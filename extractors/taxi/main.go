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
	TripID                  string  `json:"trip_id"`
	TaxiID                  string  `json:"taxi_id,omitempty"`
	TripStartTimestamp      string  `json:"trip_start_timestamp"`
	TripEndTimestamp        string  `json:"trip_end_timestamp,omitempty"`
	TripSeconds             int     `json:"trip_seconds,omitempty"`
	TripMiles               float64 `json:"trip_miles,omitempty"`
	PickupCensusTract       string  `json:"pickup_census_tract,omitempty"`
	PickupCommunityArea     string  `json:"pickup_community_area,omitempty"`
	PickupCentroidLatitude  float64 `json:"pickup_centroid_latitude,omitempty"`
	PickupCentroidLongitude float64 `json:"pickup_centroid_longitude,omitempty"`
	DropoffCentroidLatitude  float64 `json:"dropoff_centroid_latitude,omitempty"`
	DropoffCentroidLongitude float64 `json:"dropoff_centroid_longitude,omitempty"`
	Fare                    float64 `json:"fare,omitempty"`
	Tips                    float64 `json:"tips,omitempty"`
	Tolls                   float64 `json:"tolls,omitempty"`
	Extras                  float64 `json:"extras,omitempty"`
	TripTotal               float64 `json:"trip_total,omitempty"`
	PaymentType             string  `json:"payment_type,omitempty"`
	Company                 string  `json:"company,omitempty"`
}

type ExtractorConfig struct {
	Mode         string // "incremental" or "full"
	StartDate    string // YYYY-MM-DD
	EndDate      string // YYYY-MM-DD
	OutputBucket string // gs://bucket-name/path/
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

	log.Printf("Starting taxi extractor with config: %+v", config)

	// Build SODA API query
	query := buildQuery(config)
	log.Printf("Query: %s", query)

	// Extract data from Chicago API
	trips, err := extractData(query)
	if err != nil {
		log.Fatalf("Error extracting data: %v", err)
	}

	log.Printf("Extracted %d trips", len(trips))

	// Upload to Cloud Storage
	if err := uploadToGCS(config.OutputBucket, trips); err != nil {
		log.Fatalf("Error uploading to GCS: %v", err)
	}

	log.Printf("Successfully completed extraction")
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

func extractData(queryURL string) ([]TaxiTrip, error) {
	// Make HTTP request to Chicago API
	resp, err := http.Get(queryURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch data: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
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

	return trips, nil
}

func uploadToGCS(bucket string, trips []TaxiTrip) error {
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

	// TODO: Parse bucket name and create object
	// For now, just log success
	log.Printf("Would upload %d bytes to %s", len(jsonLines), bucket)

	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
