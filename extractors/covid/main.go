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
	// Chicago Data Portal API endpoint for COVID-19 Cases by ZIP
	baseURL = "https://data.cityofchicago.org/resource/yhhz-zm2v.json"

	// Batch size for pagination
	batchSize = 50000

	// GCP Project ID
	projectID = "chicago-bi-app-msds-432-476520"

	// BigQuery dataset and table
	datasetID = "raw_data"
	tableID   = "raw_covid19_cases_by_zip"

	// Concurrency settings
	maxConcurrentRequests = 5
	maxRetries            = 3
	retryDelay            = 5 * time.Second
)

type CovidCase struct {
	// Geographic & temporal
	ZipCode    string `json:"zip_code,omitempty" bigquery:"zip_code"`
	WeekNumber int64  `json:"week_number,omitempty,string" bigquery:"week_number"`
	WeekStart  string `json:"week_start,omitempty" bigquery:"week_start"`
	WeekEnd    string `json:"week_end,omitempty" bigquery:"week_end"`

	// Case metrics
	CasesWeekly          int64   `json:"cases_weekly,omitempty,string" bigquery:"cases_weekly"`
	CasesCumulative      int64   `json:"cases_cumulative,omitempty,string" bigquery:"cases_cumulative"`
	CaseRateWeekly       float64 `json:"case_rate_weekly,omitempty,string" bigquery:"case_rate_weekly"`
	CaseRateCumulative   float64 `json:"case_rate_cumulative,omitempty,string" bigquery:"case_rate_cumulative"`

	// Testing data
	TestsWeekly                       int64   `json:"tests_weekly,omitempty,string" bigquery:"tests_weekly"`
	TestsCumulative                   int64   `json:"tests_cumulative,omitempty,string" bigquery:"tests_cumulative"`
	TestRateWeekly                    float64 `json:"test_rate_weekly,omitempty,string" bigquery:"test_rate_weekly"`
	TestRateCumulative                float64 `json:"test_rate_cumulative,omitempty,string" bigquery:"test_rate_cumulative"`
	PercentTestedPositiveWeekly       float64 `json:"percent_tested_positive_weekly,omitempty,string" bigquery:"percent_tested_positive_weekly"`
	PercentTestedPositiveCumulative   float64 `json:"percent_tested_positive_cumulative,omitempty,string" bigquery:"percent_tested_positive_cumulative"`

	// Mortality
	DeathsWeekly         int64   `json:"deaths_weekly,omitempty,string" bigquery:"deaths_weekly"`
	DeathsCumulative     int64   `json:"deaths_cumulative,omitempty,string" bigquery:"deaths_cumulative"`
	DeathRateWeekly      float64 `json:"death_rate_weekly,omitempty,string" bigquery:"death_rate_weekly"`
	DeathRateCumulative  float64 `json:"death_rate_cumulative,omitempty,string" bigquery:"death_rate_cumulative"`

	// Location & administrative
	Population       int64  `json:"population,omitempty,string" bigquery:"population"`
	RowID            string `json:"row_id,omitempty" bigquery:"row_id"`

	// Coordinates (point field excluded from BigQuery)
	ZipCodeLocation interface{} `json:"-" bigquery:"-"`
}

type ExtractorConfig struct {
	Mode         string  // "incremental" or "full"
	StartDate    string  // YYYY-MM-DD (week_start)
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
	log.Println("🦠 Chicago COVID-19 Cases Extractor v1.0.0")
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
		StartDate:    getEnv("START_DATE", time.Now().AddDate(0, 0, -7).Format("2006-01-02")), // Default: last week
		EndDate:      getEnv("END_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		OutputBucket: getEnv("OUTPUT_BUCKET", "gs://chicago-bi-app-msds-432-476520-landing/covid19/"),
		SampleRate:   1.0,
		KeyID:        keyID,
		KeySecret:    keySecret,
	}

	log.Printf("📋 Configuration:")
	log.Printf("   Mode: %s", config.Mode)
	log.Printf("   Week Start: %s", config.StartDate)
	log.Printf("   Bucket: %s", config.OutputBucket)
	log.Println("")

	// Step 1: Extract data with pagination and concurrency
	startTime := time.Now()
	cases, err := extractAllDataConcurrent(ctx, config)
	if err != nil {
		log.Fatalf("❌ ERROR: Failed to extract data: %v", err)
	}
	extractDuration := time.Since(startTime)

	// Validate data
	if len(cases) == 0 {
		log.Fatalf("❌ ERROR: No COVID-19 cases extracted for week starting %s. This may indicate an API issue or invalid date.", config.StartDate)
	}

	log.Printf("✅ Extracted %d COVID-19 records in %.2f seconds", len(cases), extractDuration.Seconds())
	log.Println("")

	// Step 2: Upload to Cloud Storage
	log.Println("☁️  Uploading to Cloud Storage...")
	gcsPath, err := uploadToGCS(ctx, config.OutputBucket, cases, config.StartDate)
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
		log.Printf("✅ Verified %d rows in BigQuery for week starting %s", verifiedCount, config.StartDate)
	}

	totalDuration := time.Since(startTime)
	log.Println("")
	log.Println("========================================")
	log.Printf("✅ Extraction completed successfully!")
	log.Printf("   Total time: %.2f seconds", totalDuration.Seconds())
	log.Printf("   COVID-19 records extracted: %d", len(cases))
	log.Printf("   Rows loaded: %d", rowsLoaded)
	log.Println("========================================")
}

// Extract all data with concurrent pagination
func extractAllDataConcurrent(ctx context.Context, config ExtractorConfig) ([]CovidCase, error) {
	log.Println("🔄 Starting concurrent data extraction...")

	var (
		allCases []CovidCase
		mu       sync.Mutex
		wg       sync.WaitGroup
	)

	// Semaphore to limit concurrent requests
	sem := make(chan struct{}, maxConcurrentRequests)

	// Channel for batch results
	type batchResult struct {
		batchNum int
		offset   int
		cases    []CovidCase
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
				cases, err := extractBatchWithRetry(query, config.KeyID, config.KeySecret, maxRetries)

				// Send result
				resultChan <- batchResult{
					batchNum: batch,
					offset:   off,
					cases:    cases,
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
		if len(result.cases) > 0 {
			log.Printf("   Batch %d: Retrieved %d COVID-19 records (offset %d)", result.batchNum+1, len(result.cases), result.offset)
			mu.Lock()
			allCases = append(allCases, result.cases...)
			mu.Unlock()
		} else {
			log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
		}

		// Only stop if this batch has data AND returned fewer than expected
		// OR if we've gone past offset 0 and hit empty results
		if len(result.cases) < batchSize {
			// Track highest offset processed
			if result.offset > maxProcessedOffset {
				maxProcessedOffset = result.offset
			}

			// Stop launching new batches - finish processing what's in flight
			if len(result.cases) > 0 || result.offset == 0 {
				done = true
			}
		}
	}

	// Wait for all remaining goroutines to complete and collect their results
	for activeBatches > 0 {
		result := <-resultChan
		activeBatches--

		if result.err == nil {
			if len(result.cases) > 0 {
				log.Printf("   Batch %d: Retrieved %d COVID-19 records (offset %d)", result.batchNum+1, len(result.cases), result.offset)
				mu.Lock()
				allCases = append(allCases, result.cases...)
				mu.Unlock()
			} else {
				log.Printf("   Batch %d: No more data (offset %d)", result.batchNum+1, result.offset)
			}
		}
	}

	wg.Wait()
	close(resultChan)

	log.Printf("✅ Data extraction complete: %d total COVID-19 records collected", len(allCases))

	return allCases, nil
}

func buildQueryWithOffset(config ExtractorConfig, offset int) string {
	// Build SoQL query - extract all records for week starting on the date
	// COVID-19 data is organized by week_start
	whereClause := fmt.Sprintf(
		"week_start='%sT00:00:00'",
		config.StartDate,
	)

	return fmt.Sprintf("%s?$where=%s&$limit=%d&$offset=%d", baseURL, url.QueryEscape(whereClause), batchSize, offset)
}

// Extract batch with retry logic
func extractBatchWithRetry(queryURL, keyID, keySecret string, maxRetries int) ([]CovidCase, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		cases, err := extractDataWithAuth(queryURL, keyID, keySecret)
		if err == nil {
			return cases, nil
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
func extractDataWithAuth(queryURL, keyID, keySecret string) ([]CovidCase, error) {
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

	var cases []CovidCase
	if err := json.Unmarshal(body, &cases); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	log.Printf("🔍 DEBUG: API returned %d records", len(cases))
	return cases, nil
}

func uploadToGCS(ctx context.Context, bucketPath string, cases []CovidCase, weekStart string) (string, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	// Convert cases to newline-delimited JSON
	var jsonLines []byte
	for _, c := range cases {
		line, err := json.Marshal(c)
		if err != nil {
			return "", fmt.Errorf("failed to marshal COVID case: %w", err)
		}
		jsonLines = append(jsonLines, line...)
		jsonLines = append(jsonLines, '\n')
	}

	// Parse bucket name from path
	bucketName := "chicago-bi-app-msds-432-476520-landing"

	// Create object path with extraction week_start date
	objectPath := fmt.Sprintf("covid19/%s/data.json", weekStart)

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
	log.Printf("   Uploaded %d bytes (%d COVID-19 records)", len(jsonLines), len(cases))

	return gcsPath, nil
}

// Load data from GCS to BigQuery
func loadToBigQuery(ctx context.Context, gcsPath, weekStart string) (int64, error) {
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
func verifyBigQueryData(ctx context.Context, weekStart string) (int64, error) {
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return 0, fmt.Errorf("failed to create BigQuery client: %w", err)
	}
	defer client.Close()

	query := client.Query(fmt.Sprintf(`
		SELECT COUNT(*) as count
		FROM `+"`%s.%s.%s`"+`
		WHERE DATE(week_start) = '%s'
	`, projectID, datasetID, tableID, weekStart))

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
