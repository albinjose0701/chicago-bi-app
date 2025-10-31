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
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

const (
	// Chicago Data Portal API endpoint for TNP Trips (Transportation Network Providers - Uber/Lyft)
	baseURL = "https://data.cityofchicago.org/resource/m6dm-c72p.json"

	// Batch size for pagination
	batchSize = 50000

	// GCP Project ID
	projectID = "chicago-bi-app-msds-432-476520"
)

type TNPTrip struct {
	// Text fields
	TripID string `json:"trip_id"`

	// Timestamp fields (floating_timestamp in API)
	TripStartTimestamp string `json:"trip_start_timestamp"`
	TripEndTimestamp   string `json:"trip_end_timestamp,omitempty"`

	// Number fields (stored as strings for safe JSON parsing)
	TripSeconds         string `json:"trip_seconds,omitempty"`
	TripMiles           string `json:"trip_miles,omitempty"`
	PickupCommunityArea string `json:"pickup_community_area,omitempty"`
	DropoffCommunityArea string `json:"dropoff_community_area,omitempty"`
	Fare                string `json:"fare,omitempty"`
	Tip                 string `json:"tip,omitempty"`
	AdditionalCharges   string `json:"additional_charges,omitempty"`
	TripTotal           string `json:"trip_total,omitempty"`
	TripsPooled         string `json:"trips_pooled,omitempty"`

	// Boolean fields
	SharedTripAuthorized interface{} `json:"shared_trip_authorized,omitempty"`

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

	// Load Socrata API credentials from Secret Manager
	log.Println("Loading Socrata API credentials from Secret Manager...")
	keyID, err := getSecret(ctx, "socrata-key-id")
	if err != nil {
		log.Fatalf("ERROR: Failed to get socrata-key-id: %v", err)
	}

	keySecret, err := getSecret(ctx, "socrata-key-secret")
	if err != nil {
		log.Fatalf("ERROR: Failed to get socrata-key-secret: %v", err)
	}

	log.Println("✅ Socrata API credentials loaded successfully")

	// Load configuration from environment variables
	config := ExtractorConfig{
		Mode:         getEnv("MODE", "incremental"),
		StartDate:    getEnv("START_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		EndDate:      getEnv("END_DATE", time.Now().AddDate(0, 0, -1).Format("2006-01-02")),
		OutputBucket: getEnv("OUTPUT_BUCKET", "gs://chicago-bi-landing/tnp/"),
		SampleRate:   1.0,
		KeyID:        keyID,
		KeySecret:    keySecret,
	}

	log.Printf("Starting TNP trips extractor with config (credentials redacted): Mode=%s, StartDate=%s, EndDate=%s",
		config.Mode, config.StartDate, config.EndDate)

	// Build SODA API query
	query := buildQuery(config)
	log.Printf("Query: %s", query)

	// Extract data from Chicago API with authentication
	trips, err := extractDataWithAuth(query, config.KeyID, config.KeySecret)
	if err != nil {
		log.Fatalf("ERROR: Failed to extract data: %v", err)
	}

	log.Printf("✅ Extracted %d TNP trips", len(trips))

	// Upload to Cloud Storage
	if err := uploadToGCS(config.OutputBucket, trips, config.StartDate); err != nil {
		log.Fatalf("ERROR: Failed to upload to GCS: %v", err)
	}

	log.Printf("✅ Successfully completed TNP trips extraction")
}

func buildQuery(config ExtractorConfig) string {
	// Build SoQL query for Chicago Data Portal
	// Example: ?$where=date_trunc_ymd(trip_start_timestamp)='2025-10-29'
	whereClause := fmt.Sprintf(
		"date_trunc_ymd(trip_start_timestamp)='%s'",
		config.StartDate,
	)

	return fmt.Sprintf("%s?$where=%s&$limit=%d", baseURL, whereClause, batchSize)
}

// Extract data with Socrata API authentication
func extractDataWithAuth(queryURL, keyID, keySecret string) ([]TNPTrip, error) {
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

	log.Println("Making authenticated request to Socrata API...")
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

	log.Printf("✅ API responded with status: %d", resp.StatusCode)

	// Check rate limit headers (if present)
	if rateLimit := resp.Header.Get("X-RateLimit-Limit"); rateLimit != "" {
		log.Printf("ℹ️  Rate Limit: %s requests/hour", rateLimit)
	}
	if remaining := resp.Header.Get("X-RateLimit-Remaining"); remaining != "" {
		log.Printf("ℹ️  Remaining: %s requests", remaining)
	}

	// Parse JSON response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var trips []TNPTrip
	if err := json.Unmarshal(body, &trips); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	return trips, nil
}

func uploadToGCS(bucketPath string, trips []TNPTrip, date string) error {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	// Convert trips to newline-delimited JSON
	var jsonLines []byte
	for _, trip := range trips {
		line, err := json.Marshal(trip)
		if err != nil {
			return fmt.Errorf("failed to marshal trip: %w", err)
		}
		jsonLines = append(jsonLines, line...)
		jsonLines = append(jsonLines, '\n')
	}

	// Parse bucket name from path (e.g., "gs://bucket-name/path/")
	bucketName := "chicago-bi-app-msds-432-476520-landing"

	// Create object path with extraction date
	objectPath := fmt.Sprintf("tnp/%s/data.json", date)

	// Get bucket and object
	bucket := client.Bucket(bucketName)
	object := bucket.Object(objectPath)

	// Create writer
	writer := object.NewWriter(ctx)
	writer.ContentType = "application/json"

	// Write data
	if _, err := writer.Write(jsonLines); err != nil {
		return fmt.Errorf("failed to write to GCS: %w", err)
	}

	// Close writer
	if err := writer.Close(); err != nil {
		return fmt.Errorf("failed to close GCS writer: %w", err)
	}

	log.Printf("✅ Uploaded %d bytes to gs://%s/%s", len(jsonLines), bucketName, objectPath)

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
