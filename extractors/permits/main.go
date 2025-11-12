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
	// Chicago Data Portal API endpoint for Building Permits
	baseURL = "https://data.cityofchicago.org/resource/ydr8-5enu.json"

	// Batch size for pagination
	batchSize = 50000

	// GCP Project ID
	projectID = "chicago-bi-app-msds-432-476520"

	// BigQuery dataset and table
	datasetID = "raw_data"
	tableID   = "raw_building_permits"

	// Concurrency settings
	maxConcurrentRequests = 5
	maxRetries            = 3
	retryDelay            = 5 * time.Second
)

type BuildingPermit struct {
	// Identity fields
	ID      string `json:"id" bigquery:"id"`
	Permit  string `json:"permit_,omitempty" bigquery:"permit_"`
	RowID   string `json:"row_id,omitempty" bigquery:"row_id"`

	// Status and type fields
	PermitStatus    string `json:"permit_status,omitempty" bigquery:"permit_status"`
	PermitMilestone string `json:"permit_milestone,omitempty" bigquery:"permit_milestone"`
	PermitType      string `json:"permit_type,omitempty" bigquery:"permit_type"`
	ReviewType      string `json:"review_type,omitempty" bigquery:"review_type"`

	// Date fields
	ApplicationStartDate string `json:"application_start_date,omitempty" bigquery:"application_start_date"`
	IssueDate            string `json:"issue_date,omitempty" bigquery:"issue_date"`

	// Numeric fields
	ProcessingTime int64 `json:"processing_time,omitempty,string" bigquery:"processing_time"`

	// Address fields
	StreetNumber    int64  `json:"street_number,omitempty,string" bigquery:"street_number"`
	StreetDirection string `json:"street_direction,omitempty" bigquery:"street_direction"`
	StreetName      string `json:"street_name,omitempty" bigquery:"street_name"`

	// Work details
	WorkType        string `json:"work_type,omitempty" bigquery:"work_type"`
	WorkDescription string `json:"work_description,omitempty" bigquery:"work_description"`
	PermitCondition string `json:"permit_condition,omitempty" bigquery:"permit_condition"`

	// Fee fields - Building
	BuildingFeePaid     float64 `json:"building_fee_paid,omitempty,string" bigquery:"building_fee_paid"`
	BuildingFeeUnpaid   float64 `json:"building_fee_unpaid,omitempty,string" bigquery:"building_fee_unpaid"`
	BuildingFeeWaived   float64 `json:"building_fee_waived,omitempty,string" bigquery:"building_fee_waived"`
	BuildingFeeSubtotal float64 `json:"building_fee_subtotal,omitempty,string" bigquery:"building_fee_subtotal"`

	// Fee fields - Zoning
	ZoningFeePaid     float64 `json:"zoning_fee_paid,omitempty,string" bigquery:"zoning_fee_paid"`
	ZoningFeeUnpaid   float64 `json:"zoning_fee_unpaid,omitempty,string" bigquery:"zoning_fee_unpaid"`
	ZoningFeeWaived   float64 `json:"zoning_fee_waived,omitempty,string" bigquery:"zoning_fee_waived"`
	ZoningFeeSubtotal float64 `json:"zoning_fee_subtotal,omitempty,string" bigquery:"zoning_fee_subtotal"`

	// Fee fields - Other
	OtherFeePaid     float64 `json:"other_fee_paid,omitempty,string" bigquery:"other_fee_paid"`
	OtherFeeUnpaid   float64 `json:"other_fee_unpaid,omitempty,string" bigquery:"other_fee_unpaid"`
	OtherFeeWaived   float64 `json:"other_fee_waived,omitempty,string" bigquery:"other_fee_waived"`
	OtherFeeSubtotal float64 `json:"other_fee_subtotal,omitempty,string" bigquery:"other_fee_subtotal"`

	// Fee totals
	SubtotalPaid   float64 `json:"subtotal_paid,omitempty,string" bigquery:"subtotal_paid"`
	SubtotalUnpaid float64 `json:"subtotal_unpaid,omitempty,string" bigquery:"subtotal_unpaid"`
	SubtotalWaived float64 `json:"subtotal_waived,omitempty,string" bigquery:"subtotal_waived"`
	TotalFee       float64 `json:"total_fee,omitempty,string" bigquery:"total_fee"`

	// Contact 1
	Contact1Type    string `json:"contact_1_type,omitempty" bigquery:"contact_1_type"`
	Contact1Name    string `json:"contact_1_name,omitempty" bigquery:"contact_1_name"`
	Contact1City    string `json:"contact_1_city,omitempty" bigquery:"contact_1_city"`
	Contact1State   string `json:"contact_1_state,omitempty" bigquery:"contact_1_state"`
	Contact1Zipcode string `json:"contact_1_zipcode,omitempty" bigquery:"contact_1_zipcode"`

	// Contact 2
	Contact2Type    string `json:"contact_2_type,omitempty" bigquery:"contact_2_type"`
	Contact2Name    string `json:"contact_2_name,omitempty" bigquery:"contact_2_name"`
	Contact2City    string `json:"contact_2_city,omitempty" bigquery:"contact_2_city"`
	Contact2State   string `json:"contact_2_state,omitempty" bigquery:"contact_2_state"`
	Contact2Zipcode string `json:"contact_2_zipcode,omitempty" bigquery:"contact_2_zipcode"`

	// Contact 3
	Contact3Type    string `json:"contact_3_type,omitempty" bigquery:"contact_3_type"`
	Contact3Name    string `json:"contact_3_name,omitempty" bigquery:"contact_3_name"`
	Contact3City    string `json:"contact_3_city,omitempty" bigquery:"contact_3_city"`
	Contact3State   string `json:"contact_3_state,omitempty" bigquery:"contact_3_state"`
	Contact3Zipcode string `json:"contact_3_zipcode,omitempty" bigquery:"contact_3_zipcode"`

	// Contact 4
	Contact4Type    string `json:"contact_4_type,omitempty" bigquery:"contact_4_type"`
	Contact4Name    string `json:"contact_4_name,omitempty" bigquery:"contact_4_name"`
	Contact4City    string `json:"contact_4_city,omitempty" bigquery:"contact_4_city"`
	Contact4State   string `json:"contact_4_state,omitempty" bigquery:"contact_4_state"`
	Contact4Zipcode string `json:"contact_4_zipcode,omitempty" bigquery:"contact_4_zipcode"`

	// Contact 5
	Contact5Type    string `json:"contact_5_type,omitempty" bigquery:"contact_5_type"`
	Contact5Name    string `json:"contact_5_name,omitempty" bigquery:"contact_5_name"`
	Contact5City    string `json:"contact_5_city,omitempty" bigquery:"contact_5_city"`
	Contact5State   string `json:"contact_5_state,omitempty" bigquery:"contact_5_state"`
	Contact5Zipcode string `json:"contact_5_zipcode,omitempty" bigquery:"contact_5_zipcode"`

	// Additional fields
	ReportedCost  float64 `json:"reported_cost,omitempty,string" bigquery:"reported_cost"`
	PinList       string  `json:"pin_list,omitempty" bigquery:"pin_list"`
	CommunityArea int64   `json:"community_area,omitempty,string" bigquery:"community_area"`
	CensusTract   int64   `json:"census_tract,omitempty,string" bigquery:"census_tract"`
	Ward          int64   `json:"ward,omitempty,string" bigquery:"ward"`

	// Coordinates
	XCoordinate float64 `json:"xcoordinate,omitempty,string" bigquery:"xcoordinate"`
	YCoordinate float64 `json:"ycoordinate,omitempty,string" bigquery:"ycoordinate"`
	Latitude    float64 `json:"latitude,omitempty,string" bigquery:"latitude"`
	Longitude   float64 `json:"longitude,omitempty,string" bigquery:"longitude"`

	// Point field (excluded from BigQuery)
	Location interface{} `json:"-" bigquery:"-"`
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
	log.Println("🏗️  Chicago Building Permits Extractor v1.0.0")
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
		OutputBucket: getEnv("OUTPUT_BUCKET", "gs://chicago-bi-app-msds-432-476520-landing/permits/"),
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
	permits, err := extractAllDataConcurrent(ctx, config)
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to extract data: %v", err)
	}
	extractDuration := time.Since(startTime)

	// Validate data
	if len(permits) == 0 {
		log.Fatalf("❌ ERROR: No permits extracted for date %s. This may indicate an API issue or invalid date.", config.StartDate)
	}

	log.Printf("✅ Extracted %d permits in %.2f seconds", len(permits), extractDuration.Seconds())
	log.Println("")

	// Step 2: Upload to Cloud Storage
	log.Println("☁️  Uploading to Cloud Storage...")
	gcsPath, err := uploadToGCS(ctx, config.OutputBucket, permits, config.StartDate)
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
	log.Printf("   Permits extracted: %d", len(permits))
	log.Printf("   Rows loaded: %d", rowsLoaded)
	log.Println("========================================")
}

// Extract all data with concurrent pagination
func extractAllDataConcurrent(ctx context.Context, config ExtractorConfig) ([]BuildingPermit, error) {
	log.Println("🔄 Starting concurrent data extraction...")

	var (
		allPermits []BuildingPermit
		mu         sync.Mutex
		wg         sync.WaitGroup
	)

	// Semaphore to limit concurrent requests
	sem := make(chan struct{}, maxConcurrentRequests)

	// Channel for batch results
	type batchResult struct {
		batchNum int
		offset   int
		permits  []BuildingPermit
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
				permits, err := extractBatchWithRetry(query, config.KeyID, config.KeySecret, maxRetries)

				// Send result
				resultChan <- batchResult{
					batchNum: batch,
					offset:   off,
					permits:  permits,
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
		if len(result.permits) > 0 {
			log.Printf("   Batch %d: Retrieved %d permits (offset %d)", result.batchNum+1, len(result.permits), result.offset)
			mu.Lock()
			allPermits = append(allPermits, result.permits...)
			mu.Unlock()
		} else {
			log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
		}

		// Only stop if this batch has data AND returned fewer than expected
		// OR if we've gone past offset 0 and hit empty results
		if len(result.permits) < batchSize {
			// Track highest offset processed
			if result.offset > maxProcessedOffset {
				maxProcessedOffset = result.offset
			}

			// Stop launching new batches - finish processing what's in flight
			if len(result.permits) > 0 || result.offset == 0 {
				done = true
			}
		}
	}

	// Wait for all remaining goroutines to complete and collect their results
	for activeBatches > 0 {
		result := <-resultChan
		activeBatches--

		if result.err == nil {
			if len(result.permits) > 0 {
				log.Printf("   Batch %d: Retrieved %d permits (offset %d)", result.batchNum+1, len(result.permits), result.offset)
				mu.Lock()
				allPermits = append(allPermits, result.permits...)
				mu.Unlock()
			} else {
				log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
			}
		}
	}

	wg.Wait()
	close(resultChan)

	log.Printf("✅ Data extraction complete: %d total permits collected", len(allPermits))

	return allPermits, nil
}

func buildQueryWithOffset(config ExtractorConfig, offset int) string {
	// Build SoQL query - extract all permits issued on the date
	// Use issue_date for filtering
	whereClause := fmt.Sprintf(
		"issue_date>='%sT00:00:00' AND issue_date<'%sT00:00:00'",
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
func extractBatchWithRetry(queryURL, keyID, keySecret string, maxRetries int) ([]BuildingPermit, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		permits, err := extractDataWithAuth(queryURL, keyID, keySecret)
		if err == nil {
			return permits, nil
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
func extractDataWithAuth(queryURL, keyID, keySecret string) ([]BuildingPermit, error) {
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

	var permits []BuildingPermit
	if err := json.Unmarshal(body, &permits); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	log.Printf("🔍 DEBUG: API returned %d records", len(permits))
	return permits, nil
}

func uploadToGCS(ctx context.Context, bucketPath string, permits []BuildingPermit, date string) (string, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	// Convert permits to newline-delimited JSON
	var jsonLines []byte
	for _, permit := range permits {
		line, err := json.Marshal(permit)
		if err != nil {
			return "", fmt.Errorf("failed to marshal permit: %w", err)
		}
		jsonLines = append(jsonLines, line...)
		jsonLines = append(jsonLines, '\n')
	}

	// Parse bucket name from path
	bucketName := "chicago-bi-app-msds-432-476520-landing"

	// Create object path with extraction date
	objectPath := fmt.Sprintf("permits/%s/data.json", date)

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
	log.Printf("   Uploaded %d bytes (%d permits)", len(jsonLines), len(permits))

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

	// Create GCS reference - use existing table schema
	gcsRef := bigquery.NewGCSReference(gcsPath)
	gcsRef.SourceFormat = bigquery.JSON

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
		WHERE DATE(issue_date) = '%s'
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
