package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	_ "github.com/lib/pq"
)

const (
	// Chicago Data Portal API endpoint for TNP Trips
	baseURL = "https://data.cityofchicago.org/resource/m6dm-c72p.json"

	// Batch size for pagination
	batchSize = 50000

	// Concurrency settings
	maxConcurrentRequests = 5
	maxRetries            = 3
	retryDelay            = 5 * time.Second

	// PostgreSQL connection
	postgresHost     = "localhost"
	postgresPort     = 5432
	postgresUser     = "admin"
	postgresPassword = "admin123"
	postgresDB       = "chicago_bi_local"
)

type TNPTrip struct {
	TripID                   string      `json:"trip_id"`
	TripStartTimestamp       string      `json:"trip_start_timestamp"`
	TripEndTimestamp         string      `json:"trip_end_timestamp,omitempty"`
	TripSeconds              string      `json:"trip_seconds,omitempty"`
	TripMiles                string      `json:"trip_miles,omitempty"`
	PickupCommunityArea      string      `json:"pickup_community_area,omitempty"`
	DropoffCommunityArea     string      `json:"dropoff_community_area,omitempty"`
	Fare                     string      `json:"fare,omitempty"`
	Tip                      string      `json:"tip,omitempty"`
	AdditionalCharges        string      `json:"additional_charges,omitempty"`
	TripTotal                string      `json:"trip_total,omitempty"`
	SharedTripAuthorized     interface{} `json:"shared_trip_authorized,omitempty"`
	TripsPooled              string      `json:"trips_pooled,omitempty"`
	PickupCensusTract        string      `json:"pickup_census_tract,omitempty"`
	DropoffCensusTract       string      `json:"dropoff_census_tract,omitempty"`
	PickupCentroidLatitude   string      `json:"pickup_centroid_latitude,omitempty"`
	PickupCentroidLongitude  string      `json:"pickup_centroid_longitude,omitempty"`
	DropoffCentroidLatitude  string      `json:"dropoff_centroid_latitude,omitempty"`
	DropoffCentroidLongitude string      `json:"dropoff_centroid_longitude,omitempty"`
}

func main() {
	ctx := context.Background()

	log.Println("========================================")
	log.Println("🚗 Chicago TNP Local Extractor - 2 Weeks Test")
	log.Println("========================================")

	// Connect to PostgreSQL
	log.Println("📡 Connecting to PostgreSQL...")
	connStr := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		postgresHost, postgresPort, postgresUser, postgresPassword, postgresDB)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("❌ Failed to connect to PostgreSQL: %v", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("❌ Failed to ping PostgreSQL: %v", err)
	}
	log.Println("✅ Connected to PostgreSQL")

	// Get Socrata credentials from environment or use demo
	keyID := os.Getenv("SOCRATA_KEY_ID")
	keySecret := os.Getenv("SOCRATA_KEY_SECRET")

	if keyID == "" {
		log.Println("⚠️  No Socrata credentials found, using unauthenticated access (slower)")
	}

	// Extract 2 weeks: Jan 1-14, 2020
	startDate := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	endDate := time.Date(2020, 1, 14, 23, 59, 59, 0, time.UTC)

	log.Printf("📋 Configuration:")
	log.Printf("   Period: %s to %s (14 days)", startDate.Format("2006-01-02"), endDate.Format("2006-01-02"))
	log.Printf("   Database: %s@%s:%d/%s", postgresUser, postgresHost, postgresPort, postgresDB)
	log.Println("")

	totalStartTime := time.Now()
	totalTrips := 0
	totalRows := 0

	// Extract each day
	for currentDate := startDate; currentDate.Before(endDate) || currentDate.Equal(endDate); currentDate = currentDate.AddDate(0, 0, 1) {
		dateStr := currentDate.Format("2006-01-02")
		log.Printf("📅 Processing date: %s", dateStr)

		dayStartTime := time.Now()

		// Extract data for this date
		trips, err := extractAllDataConcurrent(ctx, dateStr, keyID, keySecret)
		if err != nil {
			log.Printf("❌ Failed to extract data for %s: %v", dateStr, err)
			continue
		}

		if len(trips) == 0 {
			log.Printf("⚠️  No trips found for %s", dateStr)
			continue
		}

		log.Printf("   Extracted %d trips in %.2fs", len(trips), time.Since(dayStartTime).Seconds())

		// Insert into PostgreSQL
		insertStartTime := time.Now()
		rowsInserted, err := insertTripsToPostgres(ctx, db, trips)
		if err != nil {
			log.Printf("❌ Failed to insert data for %s: %v", dateStr, err)
			continue
		}

		insertDuration := time.Since(insertStartTime)
		dayDuration := time.Since(dayStartTime)

		totalTrips += len(trips)
		totalRows += rowsInserted

		log.Printf("✅ Day complete: %d trips extracted, %d rows inserted", len(trips), rowsInserted)
		log.Printf("   Extraction: %.2fs, Insertion: %.2fs, Total: %.2fs",
			dayStartTime.Add(insertStartTime.Sub(dayStartTime)).Sub(dayStartTime).Seconds(),
			insertDuration.Seconds(),
			dayDuration.Seconds())
		log.Println("")
	}

	totalDuration := time.Since(totalStartTime)

	log.Println("========================================")
	log.Println("✅ Extraction Complete!")
	log.Println("========================================")
	log.Printf("Total Duration: %.2f seconds (%.2f minutes)", totalDuration.Seconds(), totalDuration.Minutes())
	log.Printf("Total Trips Extracted: %d", totalTrips)
	log.Printf("Total Rows Inserted: %d", totalRows)
	log.Printf("Average per Day: %.0f trips, %.2f seconds", float64(totalTrips)/14, totalDuration.Seconds()/14)
	log.Println("")

	// Verify data in database
	log.Println("🔍 Verifying data in PostgreSQL...")
	verifyData(db)
}

func extractAllDataConcurrent(ctx context.Context, date, keyID, keySecret string) ([]TNPTrip, error) {
	var (
		allTrips []TNPTrip
		mu       sync.Mutex
		wg       sync.WaitGroup
		errChan  = make(chan error, 1)
		doneChan = make(chan bool, 1)
	)

	sem := make(chan struct{}, maxConcurrentRequests)

	offset := 0
	batchNum := 0

	for {
		select {
		case err := <-errChan:
			return nil, err
		default:
		}

		wg.Add(1)
		currentOffset := offset
		currentBatch := batchNum

		go func(off, batch int) {
			defer wg.Done()

			sem <- struct{}{}
			defer func() { <-sem }()

			query := buildQueryWithOffset(date, off)
			trips, err := extractBatchWithRetry(query, keyID, keySecret, maxRetries)
			if err != nil {
				select {
				case errChan <- fmt.Errorf("batch %d failed: %w", batch, err):
				default:
				}
				return
			}

			if len(trips) > 0 {
				log.Printf("      Batch %d: %d trips (offset %d)", batch+1, len(trips), off)
				mu.Lock()
				allTrips = append(allTrips, trips...)
				mu.Unlock()
			}

			if len(trips) < batchSize {
				select {
				case doneChan <- true:
				default:
				}
			}
		}(currentOffset, currentBatch)

		time.Sleep(100 * time.Millisecond)

		select {
		case <-doneChan:
			wg.Wait()
			close(errChan)
			if err := <-errChan; err != nil {
				return nil, err
			}
			return allTrips, nil
		default:
		}

		offset += batchSize
		batchNum++

		if batchNum >= 20 {
			log.Println("      ⚠️  Reached max batch limit (20)")
			break
		}
	}

	wg.Wait()
	close(errChan)

	if err := <-errChan; err != nil {
		return nil, err
	}

	return allTrips, nil
}

func buildQueryWithOffset(date string, offset int) string {
	whereClause := fmt.Sprintf("date_trunc_ymd(trip_start_timestamp)='%s'", date)
	return fmt.Sprintf("%s?$where=%s&$limit=%d&$offset=%d", baseURL, whereClause, batchSize, offset)
}

func extractBatchWithRetry(queryURL, keyID, keySecret string, maxRetries int) ([]TNPTrip, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		trips, err := extractDataWithAuth(queryURL, keyID, keySecret)
		if err == nil {
			return trips, nil
		}

		lastErr = err
		if attempt < maxRetries {
			log.Printf("      ⚠️  Attempt %d failed, retrying...", attempt)
			time.Sleep(retryDelay)
		}
	}

	return nil, fmt.Errorf("failed after %d attempts: %w", maxRetries, lastErr)
}

func extractDataWithAuth(queryURL, keyID, keySecret string) ([]TNPTrip, error) {
	req, err := http.NewRequest("GET", queryURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	if keyID != "" && keySecret != "" {
		req.SetBasicAuth(keyID, keySecret)
	}

	req.Header.Add("Accept", "application/json")
	req.Header.Add("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 300 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("unexpected status %d: %s", resp.StatusCode, string(body))
	}

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

func insertTripsToPostgres(ctx context.Context, db *sql.DB, trips []TNPTrip) (int, error) {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx, `
		INSERT INTO tnp_trips (
			trip_id, trip_start_timestamp, trip_end_timestamp,
			trip_seconds, trip_miles, pickup_community_area, dropoff_community_area,
			fare, tip, additional_charges, trip_total, shared_trip_authorized,
			trips_pooled, pickup_census_tract, dropoff_census_tract,
			pickup_centroid_latitude, pickup_centroid_longitude,
			dropoff_centroid_latitude, dropoff_centroid_longitude
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
		ON CONFLICT (trip_id) DO NOTHING
	`)
	if err != nil {
		return 0, fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	rowsInserted := 0
	for _, trip := range trips {
		// Convert shared_trip_authorized to bool
		var sharedAuth *bool
		if trip.SharedTripAuthorized != nil {
			switch v := trip.SharedTripAuthorized.(type) {
			case bool:
				sharedAuth = &v
			case string:
				if v == "true" {
					t := true
					sharedAuth = &t
				} else if v == "false" {
					f := false
					sharedAuth = &f
				}
			}
		}

		result, err := stmt.ExecContext(ctx,
			trip.TripID,
			nullString(trip.TripStartTimestamp),
			nullString(trip.TripEndTimestamp),
			nullString(trip.TripSeconds),
			nullString(trip.TripMiles),
			nullString(trip.PickupCommunityArea),
			nullString(trip.DropoffCommunityArea),
			nullString(trip.Fare),
			nullString(trip.Tip),
			nullString(trip.AdditionalCharges),
			nullString(trip.TripTotal),
			sharedAuth,
			nullString(trip.TripsPooled),
			nullString(trip.PickupCensusTract),
			nullString(trip.DropoffCensusTract),
			nullString(trip.PickupCentroidLatitude),
			nullString(trip.PickupCentroidLongitude),
			nullString(trip.DropoffCentroidLatitude),
			nullString(trip.DropoffCentroidLongitude),
		)

		if err != nil {
			log.Printf("      ⚠️  Failed to insert trip %s: %v", trip.TripID, err)
			continue
		}

		rows, _ := result.RowsAffected()
		rowsInserted += int(rows)
	}

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit transaction: %w", err)
	}

	return rowsInserted, nil
}

func nullString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func verifyData(db *sql.DB) {
	var count int
	var minDate, maxDate string

	err := db.QueryRow(`
		SELECT COUNT(*),
		       MIN(DATE(trip_start_timestamp))::TEXT,
		       MAX(DATE(trip_start_timestamp))::TEXT
		FROM tnp_trips
	`).Scan(&count, &minDate, &maxDate)

	if err != nil {
		log.Printf("❌ Failed to verify data: %v", err)
		return
	}

	log.Printf("Total rows in database: %d", count)
	log.Printf("Date range: %s to %s", minDate, maxDate)

	// Get daily counts
	rows, err := db.Query(`
		SELECT DATE(trip_start_timestamp)::TEXT as date, COUNT(*) as count
		FROM tnp_trips
		GROUP BY DATE(trip_start_timestamp)
		ORDER BY date
	`)
	if err != nil {
		log.Printf("❌ Failed to get daily counts: %v", err)
		return
	}
	defer rows.Close()

	log.Println("\nDaily trip counts:")
	for rows.Next() {
		var date string
		var count int
		if err := rows.Scan(&date, &count); err != nil {
			continue
		}
		log.Printf("   %s: %d trips", date, count)
	}
}
