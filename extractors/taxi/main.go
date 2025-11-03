package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/storage"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"google.golang.org/api/iterator"
)

const (
	// Chicago Data Portal API endpoint for Taxi Trips
	baseURL = "https://data.cityofchicago.org/resource/wrvz-psew.json"

	// Batch size for pagination
	batchSize = 50000

	// GCP Project ID
	projectID = "chicago-bi-app-msds-432-476520"

	// BigQuery dataset and table
	datasetID = "raw_data"
	tableID   = "raw_taxi_trips"

	// Concurrency settings
	maxConcurrentRequests = 5
	maxRetries            = 3
	retryDelay            = 5 * time.Second
)

type TaxiTrip struct {
	// Text fields
	TripID      string `json:"trip_id" bigquery:"trip_id"`
	TaxiID      string `json:"taxi_id,omitempty" bigquery:"taxi_id"`
	Company     string `json:"company,omitempty" bigquery:"company"`
	PaymentType string `json:"payment_type,omitempty" bigquery:"payment_type"`

	// Timestamp fields (floating_timestamp in API)
	TripStartTimestamp string `json:"trip_start_timestamp" bigquery:"trip_start_timestamp"`
	TripEndTimestamp   string `json:"trip_end_timestamp,omitempty" bigquery:"trip_end_timestamp"`

	// Number fields - integers
	TripSeconds int64 `json:"trip_seconds,omitempty,string" bigquery:"trip_seconds"`

	// Number fields - floats
	TripMiles float64 `json:"trip_miles,omitempty,string" bigquery:"trip_miles"`
	Fare      float64 `json:"fare,omitempty,string" bigquery:"fare"`
	Tips      float64 `json:"tips,omitempty,string" bigquery:"tips"`
	Tolls     float64 `json:"tolls,omitempty,string" bigquery:"tolls"`
	Extras    float64 `json:"extras,omitempty,string" bigquery:"extras"`
	TripTotal float64 `json:"trip_total,omitempty,string" bigquery:"trip_total"`

	// Community area - strings (IDs as strings) - omitempty removed to preserve empty values
	PickupCommunityArea  string `json:"pickup_community_area" bigquery:"pickup_community_area"`
	DropoffCommunityArea string `json:"dropoff_community_area" bigquery:"dropoff_community_area"`

	// Census tract fields - omitempty removed to preserve empty values
	PickupCensusTract  string `json:"pickup_census_tract" bigquery:"pickup_census_tract"`
	DropoffCensusTract string `json:"dropoff_census_tract" bigquery:"dropoff_census_tract"`

	// Latitude/Longitude fields - floats - omitempty removed to preserve zero values
	PickupCentroidLatitude   float64 `json:"pickup_centroid_latitude,string" bigquery:"pickup_centroid_latitude"`
	PickupCentroidLongitude  float64 `json:"pickup_centroid_longitude,string" bigquery:"pickup_centroid_longitude"`
	DropoffCentroidLatitude  float64 `json:"dropoff_centroid_latitude,string" bigquery:"dropoff_centroid_latitude"`
	DropoffCentroidLongitude float64 `json:"dropoff_centroid_longitude,string" bigquery:"dropoff_centroid_longitude"`

	// Point fields (geospatial - excluded from JSON output and BigQuery)
	PickupCentroidLocation  interface{} `json:"-" bigquery:"-"`
	DropoffCentroidLocation interface{} `json:"-" bigquery:"-"`
}

type ExtractorConfig struct {
	Mode         string  // "incremental" or "full"
	StartDate    string  // YYYY-MM-DD
	EndDate      string  // YYYY-MM-DD
	OutputBucket string  // gs://bucket-name/path/
	SampleRate   float64 // 0.0 to 1.0 (1.0 = 100%)
	KeyID        string  // Socrata API Key ID (from Secret Manager)
	KeySecret    string  // Socrata API Key Secret (from Secret Manager)
}

// Get secret from GCP Secret Manager
func getSecret(ctx context.Context, secretName string) (string, error) {
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create secret manager client: %w", err)
	}
	defer client.Close()

	// Build the request
	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: fmt.Sprintf("projects/%s/secrets/%s/versions/latest", projectID, secretName),
	}

	// Access the secret
	result, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		return "", fmt.Errorf("failed to access secret %s: %w", secretName, err)
	}

	return string(result.Payload.Data), nil
}

func main() {
	ctx := context.Background()

	log.Println("========================================")
	log.Println("🚕 Chicago Taxi Trips Extractor v2.1.3")
	log.Println("========================================")

	// Load Socrata API credentials from Secret Manager
	log.Println("📡 Loading Socrata API credentials from Secret Manager...")
	keyID, err := getSecret(ctx, "socrata-key-id")
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to get socrata-key-id: %v", err)
	}

	keySecret, err := getSecret(ctx, "socrata-key-secret")
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to get socrata-key-secret: %v", err)
	}

	log.Println("✅ Socrata API credentials loaded successfully")

	// Load configuration from environment variables
	config := ExtractorConfig{
		Mode:         getEnv("MODE", "incremental"),
		StartDate:    getEnv("START_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		EndDate:      getEnv("END_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		OutputBucket: getEnv("OUTPUT_BUCKET", "gs://chicago-bi-app-msds-432-476520-landing/taxi/"),
		SampleRate:   1.0,
		KeyID:        keyID,
		KeySecret:    keySecret,
	}

	log.Printf("📋 Configuration:")
	log.Printf("   Mode: %s", config.Mode)
	log.Printf("   Date: %s", config.StartDate)
	log.Printf("   Bucket: %s", config.OutputBucket)
	log.Println("")

	// Step 1: Extract data with pagination and concurrency
	startTime := time.Now()
	trips, err := extractAllDataConcurrent(ctx, config)
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to extract data: %v", err)
	}
	extractDuration := time.Since(startTime)

	// Validate data
	if len(trips) == 0 {
		log.Fatalf("❌ ERROR: No trips extracted for date %s. This may indicate an API issue or invalid date.", config.StartDate)
	}

	log.Printf("✅ Extracted %d trips in %.2f seconds", len(trips), extractDuration.Seconds())
	log.Println("")

	// Step 2: Upload to Cloud Storage
	log.Println("☁️  Uploading to Cloud Storage...")
	gcsPath, err := uploadToGCS(ctx, config.OutputBucket, trips, config.StartDate)
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to upload to GCS: %v", err)
	}

	log.Printf("✅ Uploaded to %s", gcsPath)
	log.Println("")

	// Step 3: Load to BigQuery
	log.Println("📊 Loading to BigQuery...")
	rowsLoaded, err := loadToBigQuery(ctx, gcsPath, config.StartDate)
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to load to BigQuery: %v", err)
	}

	log.Printf("✅ Loaded %d rows to BigQuery table %s.%s", rowsLoaded, datasetID, tableID)
	log.Println("")

	// Step 4: Verify data in BigQuery
	log.Println("🔍 Verifying data in BigQuery...")
	verifiedCount, err := verifyBigQueryData(ctx, config.StartDate)
	if err != nil {
		log.Printf("⚠️  WARNING: Could not verify data: %v", err)
	} else {
		log.Printf("✅ Verified %d rows in BigQuery for date %s", verifiedCount, config.StartDate)
	}

	totalDuration := time.Since(startTime)
	log.Println("")
	log.Println("========================================")
	log.Printf("✅ Extraction completed successfully!")
	log.Printf("   Total time: %.2f seconds", totalDuration.Seconds())
	log.Printf("   Trips extracted: %d", len(trips))
	log.Printf("   Rows loaded: %d", rowsLoaded)
	log.Println("========================================")
}

// Extract all data with concurrent pagination
func extractAllDataConcurrent(ctx context.Context, config ExtractorConfig) ([]TaxiTrip, error) {
	log.Println("🔄 Starting concurrent data extraction...")

	var (
		allTrips []TaxiTrip
		mu       sync.Mutex
		wg       sync.WaitGroup
	)

	// Semaphore to limit concurrent requests
	sem := make(chan struct{}, maxConcurrentRequests)

	// Channel for batch results
	type batchResult struct {
		batchNum int
		offset   int
		trips    []TaxiTrip
		err      error
	}
	resultChan := make(chan batchResult, maxConcurrentRequests)

	// Start with offset 0, continue until we get fewer records than batchSize
	offset := 0
	batchNum := 0
	activeBatches := 0
	done := false

	// Keep track of maximum offset that has been processed
	maxProcessedOffset := -1

	for !done {
		// Launch batches up to maxConcurrentRequests without blocking
		for activeBatches < maxConcurrentRequests && !done {
			wg.Add(1)
			activeBatches++
			currentOffset := offset
			currentBatch := batchNum

			go func(off, batch int) {
				defer wg.Done()

				// Acquire semaphore
				sem <- struct{}{}
				defer func() { <-sem }()

				// Build query with offset
				query := buildQueryWithOffset(config, off)

				// Extract batch with retry logic
				trips, err := extractBatchWithRetry(query, config.KeyID, config.KeySecret, maxRetries)

				// Send result
				resultChan <- batchResult{
					batchNum: batch,
					offset:   off,
					trips:    trips,
					err:      err,
				}
			}(currentOffset, currentBatch)

			offset += batchSize
			batchNum++
		}

		// Process one result (allows next batch to launch)
		result := <-resultChan
		activeBatches--

		if result.err != nil {
			// Wait for remaining batches
			for activeBatches > 0 {
				<-resultChan
				activeBatches--
			}
			wg.Wait()
			return nil, fmt.Errorf("batch %d (offset %d) failed: %w", result.batchNum, result.offset, result.err)
		}

		// Log progress
		if len(result.trips) > 0 {
			log.Printf("   Batch %d: Retrieved %d trips (offset %d)", result.batchNum+1, len(result.trips), result.offset)
			mu.Lock()
			allTrips = append(allTrips, result.trips...)
			mu.Unlock()
		} else {
			log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
		}

		// Only stop if this batch has data AND returned fewer than expected
		// OR if we've gone past offset 0 and hit empty results
		if len(result.trips) < batchSize {
			// Track highest offset processed
			if result.offset > maxProcessedOffset {
				maxProcessedOffset = result.offset
			}

			// Stop launching new batches - finish processing what's in flight
			if len(result.trips) > 0 || result.offset == 0 {
				done = true
			}
		}
	}

	// Wait for all remaining goroutines to complete and collect their results
	for activeBatches > 0 {
		result := <-resultChan
		activeBatches--

		if result.err == nil {
			if len(result.trips) > 0 {
				log.Printf("   Batch %d: Retrieved %d trips (offset %d)", result.batchNum+1, len(result.trips), result.offset)
				mu.Lock()
				allTrips = append(allTrips, result.trips...)
				mu.Unlock()
			} else {
				log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
			}
		}
	}

	wg.Wait()
	close(resultChan)

	log.Printf("✅ Data extraction complete: %d total trips collected", len(allTrips))

	return allTrips, nil
}

func buildQueryWithOffset(config ExtractorConfig, offset int) string {
	// Build SoQL query - extract all data for the date
	// Data quality filters will be applied in BigQuery after loading
	// Use timestamp range: >= start of day AND < start of next day
	whereClause := fmt.Sprintf(
		"trip_start_timestamp>='%sT00:00:00' AND trip_start_timestamp<'%sT00:00:00'",
		config.StartDate,
		getNextDay(config.StartDate),
	)

	return fmt.Sprintf("%s?$where=%s&$limit=%d&$offset=%d", baseURL, url.QueryEscape(whereClause), batchSize, offset)
}

// Get next day in YYYY-MM-DD format
func getNextDay(dateStr string) string {
	t, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return dateStr
	}
	return t.AddDate(0, 0, 1).Format("2006-01-02")
}

// Extract batch with retry logic
func extractBatchWithRetry(queryURL, keyID, keySecret string, maxRetries int) ([]TaxiTrip, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		trips, err := extractDataWithAuth(queryURL, keyID, keySecret)
		if err == nil {
			return trips, nil
		}

		lastErr = err
		if attempt < maxRetries {
			log.Printf("⚠️  Attempt %d failed: %v. Retrying in %v...", attempt, err, retryDelay)
			time.Sleep(retryDelay)
		}
	}

	return nil, fmt.Errorf("failed after %d attempts: %w", maxRetries, lastErr)
}

// Extract data with Socrata API authentication
func extractDataWithAuth(queryURL, keyID, keySecret string) ([]TaxiTrip, error) {
	// Log the query URL for debugging
	log.Printf("🔍 DEBUG: API URL: %s", queryURL)

	// Create HTTP request
	req, err := http.NewRequest("GET", queryURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Add HTTP Basic Authentication (Socrata SODA API)
	req.SetBasicAuth(keyID, keySecret)

	// Add recommended headers
	req.Header.Add("Accept", "application/json")
	req.Header.Add("Content-Type", "application/json")

	// Make the request
	client := &http.Client{
		Timeout: 300 * time.Second, // 5-minute timeout (for slow API responses)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	// Check status code
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status code %d: %s", resp.StatusCode, string(body))
	}

	// Parse JSON response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var trips []TaxiTrip
	if err := json.Unmarshal(body, &trips); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	log.Printf("🔍 DEBUG: API returned %d records", len(trips))
	return trips, nil
}

func uploadToGCS(ctx context.Context, bucketPath string, trips []TaxiTrip, date string) (string, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	// Convert trips to newline-delimited JSON
	var jsonLines []byte
	for _, trip := range trips {
		line, err := json.Marshal(trip)
		if err != nil {
			return "", fmt.Errorf("failed to marshal trip: %w", err)
		}
		jsonLines = append(jsonLines, line...)
		jsonLines = append(jsonLines, '\n')
	}

	// Parse bucket name from path
	bucketName := "chicago-bi-app-msds-432-476520-landing"

	// Create object path with extraction date
	objectPath := fmt.Sprintf("taxi/%s/data.json", date)

	// Get bucket and object
	bucket := client.Bucket(bucketName)
	object := bucket.Object(objectPath)

	// Create writer
	writer := object.NewWriter(ctx)
	writer.ContentType = "application/json"

	// Write data
	if _, err := writer.Write(jsonLines); err != nil {
		return "", fmt.Errorf("failed to write to GCS: %w", err)
	}

	// Close writer
	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to close GCS writer: %w", err)
	}

	gcsPath := fmt.Sprintf("gs://%s/%s", bucketName, objectPath)
	log.Printf("   Uploaded %d bytes (%d trips)", len(jsonLines), len(trips))

	return gcsPath, nil
}

// Load data from GCS to BigQuery
func loadToBigQuery(ctx context.Context, gcsPath, date string) (int64, error) {
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return 0, fmt.Errorf("failed to create BigQuery client: %w", err)
	}
	defer client.Close()

	// Define table reference
	dataset := client.Dataset(datasetID)
	table := dataset.Table(tableID)

	// Create GCS reference - use existing table schema (no AutoDetect or explicit schema)
	gcsRef := bigquery.NewGCSReference(gcsPath)
	gcsRef.SourceFormat = bigquery.JSON
	// Note: Not setting AutoDetect or Schema - will use existing table schema

	// Create loader
	loader := table.LoaderFrom(gcsRef)
	loader.WriteDisposition = bigquery.WriteAppend

	// Run load job
	log.Printf("   Starting BigQuery load job...")
	job, err := loader.Run(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to start load job: %w", err)
	}

	// Wait for completion
	status, err := job.Wait(ctx)
	if err != nil {
		return 0, fmt.Errorf("load job failed: %w", err)
	}

	if status.Err() != nil {
		return 0, fmt.Errorf("load job completed with error: %v", status.Err())
	}

	// Get job statistics
	jobStatus := job.LastStatus()
	if jobStatus != nil && jobStatus.Statistics != nil {
		if loadStats, ok := jobStatus.Statistics.Details.(*bigquery.LoadStatistics); ok {
			log.Printf("   Load job completed: %d rows loaded", loadStats.OutputRows)
			return loadStats.OutputRows, nil
		}
	}

	return 0, nil
}

// Verify data was loaded to BigQuery
func verifyBigQueryData(ctx context.Context, date string) (int64, error) {
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return 0, fmt.Errorf("failed to create BigQuery client: %w", err)
	}
	defer client.Close()

	query := client.Query(fmt.Sprintf(`
		SELECT COUNT(*) as count
		FROM `+"`%s.%s.%s`"+`
		WHERE DATE(trip_start_timestamp) = '%s'
	`, projectID, datasetID, tableID, date))

	it, err := query.Read(ctx)
	if err != nil {
		return 0, fmt.Errorf("query failed: %w", err)
	}

	var row []bigquery.Value
	err = it.Next(&row)
	if err == iterator.Done {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("failed to read result: %w", err)
	}

	count, ok := row[0].(int64)
	if !ok {
		return 0, fmt.Errorf("unexpected result type")
	}

	return count, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
