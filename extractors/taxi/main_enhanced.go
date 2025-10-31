package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/storage"
)

const (
	// Chicago Data Portal API endpoint for Taxi Trips
	baseURL = "https://data.cityofchicago.org/resource/wrvz-psew.json"

	// Batch size for pagination
	batchSize = 50000
)

type TaxiTrip struct {
	// Text fields
	TripID   string `json:"trip_id"`
	TaxiID   string `json:"taxi_id,omitempty"`
	Company  string `json:"company,omitempty"`
	PaymentType string `json:"payment_type,omitempty"`

	// Timestamp fields (floating_timestamp in API)
	TripStartTimestamp string `json:"trip_start_timestamp"`
	TripEndTimestamp   string `json:"trip_end_timestamp,omitempty"`

	// Number fields (stored as strings for safe JSON parsing)
	TripSeconds         string `json:"trip_seconds,omitempty"`
	TripMiles           string `json:"trip_miles,omitempty"`
	PickupCommunityArea string `json:"pickup_community_area,omitempty"`
	DropoffCommunityArea string `json:"dropoff_community_area,omitempty"`
	Fare                string `json:"fare,omitempty"`
	Tips                string `json:"tips,omitempty"`
	Tolls               string `json:"tolls,omitempty"`
	Extras              string `json:"extras,omitempty"`
	TripTotal           string `json:"trip_total,omitempty"`

	// Census tract fields
	PickupCensusTract  string `json:"pickup_census_tract,omitempty"`
	DropoffCensusTract string `json:"dropoff_census_tract,omitempty"`

	// Latitude/Longitude fields (numbers)
	PickupCentroidLatitude   string `json:"pickup_centroid_latitude,omitempty"`
	PickupCentroidLongitude  string `json:"pickup_centroid_longitude,omitempty"`
	DropoffCentroidLatitude  string `json:"dropoff_centroid_latitude,omitempty"`
	DropoffCentroidLongitude string `json:"dropoff_centroid_longitude,omitempty"`

	// Point fields (geospatial - stored as-is from API)
	PickupCentroidLocation  interface{} `json:"pickup_centroid_location,omitempty"`
	DropoffCentroidLocation interface{} `json:"dropoff_centroid_location,omitempty"`
}

type ExtractorConfig struct {
	Mode         string  // "incremental" or "full"
	StartDate    string  // YYYY-MM-DD
	EndDate      string  // YYYY-MM-DD
	OutputBucket string  // gs://bucket-name/path/
	SampleRate   float64 // 0.0 to 1.0 (1.0 = 100%)
}

func main() {
	// Load configuration from environment variables
	config := ExtractorConfig{
		Mode:         getEnv("MODE", "incremental"),
		StartDate:    getEnv("START_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		EndDate:      getEnv("END_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		OutputBucket: getEnv("OUTPUT_BUCKET", "gs://chicago-bi-landing/taxi/"),
		SampleRate:   1.0,
	}

	log.Printf("Starting ENHANCED taxi extractor with config: %+v", config)

	// Parse dates
	startDate, err := time.Parse("2006-01-02", config.StartDate)
	if err != nil {
		log.Fatalf("Invalid START_DATE format: %v", err)
	}

	endDate, err := time.Parse("2006-01-02", config.EndDate)
	if err != nil {
		log.Fatalf("Invalid END_DATE format: %v", err)
	}

	// Validate date range
	if endDate.Before(startDate) {
		log.Fatalf("END_DATE cannot be before START_DATE")
	}

	// Calculate number of days to process
	daysDiff := int(endDate.Sub(startDate).Hours()/24) + 1
	log.Printf("Processing %d days from %s to %s", daysDiff, config.StartDate, config.EndDate)

	// Process each date in the range
	totalTrips := 0
	successDays := 0
	failedDays := 0

	currentDate := startDate
	for currentDate.Before(endDate.AddDate(0, 0, 1)) {
		dateStr := currentDate.Format("2006-01-02")
		log.Printf("Processing date: %s", dateStr)

		// Build query for this date
		query := buildQueryForDate(dateStr)
		log.Printf("Query: %s", query)

		// Extract data from Chicago API
		trips, err := extractData(query)
		if err != nil {
			log.Printf("ERROR extracting data for %s: %v", dateStr, err)
			failedDays++
			currentDate = currentDate.AddDate(0, 0, 1)
			continue
		}

		log.Printf("Extracted %d trips for %s", len(trips), dateStr)
		totalTrips += len(trips)

		// Upload to Cloud Storage
		if err := uploadToGCSForDate(config.OutputBucket, trips, dateStr); err != nil {
			log.Printf("ERROR uploading to GCS for %s: %v", dateStr, err)
			failedDays++
		} else {
			successDays++
		}

		// Move to next date
		currentDate = currentDate.AddDate(0, 0, 1)

		// Small delay to avoid rate limits (1 second between dates)
		if currentDate.Before(endDate.AddDate(0, 0, 1)) {
			log.Printf("Waiting 1 second before next date...")
			time.Sleep(1 * time.Second)
		}
	}

	// Summary
	log.Printf("========================================")
	log.Printf("EXTRACTION COMPLETE")
	log.Printf("========================================")
	log.Printf("Total days processed: %d", daysDiff)
	log.Printf("Successful: %d", successDays)
	log.Printf("Failed: %d", failedDays)
	log.Printf("Total trips extracted: %d", totalTrips)
	log.Printf("========================================")

	if failedDays > 0 {
		log.Fatalf("Completed with %d failures", failedDays)
	}

	log.Printf("Successfully completed extraction for all dates")
}

func buildQueryForDate(date string) string {
	// Build SoQL query for specific date
	whereClause := fmt.Sprintf(
		"date_trunc_ymd(trip_start_timestamp)='%s'",
		date,
	)

	return fmt.Sprintf("%s?$where=%s&$limit=%d", baseURL, whereClause, batchSize)
}

func extractData(queryURL string) ([]TaxiTrip, error) {
	// Make HTTP request to Chicago API
	resp, err := http.Get(queryURL)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	// Parse JSON
	var trips []TaxiTrip
	if err := json.Unmarshal(body, &trips); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	return trips, nil
}

func uploadToGCSForDate(bucketPath string, trips []TaxiTrip, date string) error {
	// Parse bucket path (e.g., "gs://bucket-name/path/")
	// For simplicity, assuming bucketPath format is correct

	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create storage client: %w", err)
	}
	defer client.Close()

	// Extract bucket name from path (simplified)
	// In production, use proper URL parsing
	bucketName := "chicago-bi-landing" // Hardcoded for now

	// Create object path: taxi/2020-01-01/data.json
	objectPath := fmt.Sprintf("taxi/%s/data.json", date)

	// Get bucket handle
	bucket := client.Bucket(bucketName)
	object := bucket.Object(objectPath)

	// Create writer
	writer := object.NewWriter(ctx)
	writer.ContentType = "application/json"

	// Convert trips to JSON (newline-delimited)
	for _, trip := range trips {
		tripJSON, err := json.Marshal(trip)
		if err != nil {
			return fmt.Errorf("failed to marshal trip: %w", err)
		}

		if _, err := writer.Write(append(tripJSON, '\n')); err != nil {
			return fmt.Errorf("failed to write to GCS: %w", err)
		}
	}

	// Close writer
	if err := writer.Close(); err != nil {
		return fmt.Errorf("failed to close GCS writer: %w", err)
	}

	log.Printf("Uploaded %d trips to gs://%s/%s", len(trips), bucketName, objectPath)
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
