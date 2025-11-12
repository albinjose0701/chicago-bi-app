# Data Quality Strategy - Chicago BI App

**Created:** November 6, 2025
**Purpose:** Define data quality validation approach across Bronze/Silver/Gold layers

---

## 🎯 Pipeline Architecture Overview

```
Source API → [Extractor + Critical Validation] → Bronze (Raw) → [Quality Checks] → Silver (Clean) → Gold (Aggregated)
                    ↑                                                    ↑
              Fail fast only for                            Document quality,
              catastrophic issues                           inform transformations
```

---

## 🥉 Bronze Layer - Raw Truth

### Philosophy
**Store EVERYTHING as-is from the source** - Bronze is the "replay buffer"

### What Goes in Bronze
- ✅ All records from source API
- ✅ Rows with null values (even critical fields)
- ✅ Duplicate records
- ✅ Outliers (absurdly high/low values)
- ✅ Records with invalid coordinates
- ✅ Exact schema from source

### What NOT to Do in Bronze
- ❌ Don't filter out null rows
- ❌ Don't remove outliers
- ❌ Don't deduplicate
- ❌ Don't apply business rules
- ❌ Don't transform field values

### Why?
If you make a mistake in Silver/Gold, you can reprocess from Bronze without hitting the source API again.

**Example Bronze Table:**
```sql
-- raw_data.raw_building_permits (Bronze)
-- Contains ALL data, including problematic records
SELECT
  permit_,                -- May have nulls
  total_fee,             -- May have outliers (-$999, $999,999,999)
  latitude,              -- May have nulls or invalid values (0, 999)
  community_area,        -- May have nulls or invalid IDs (99, -1)
  issue_date             -- Loaded exactly as received
FROM `raw_data.raw_building_permits`
-- NO FILTERING AT THIS STAGE
```

---

## 🥈 Silver Layer - Clean, Analysis-Ready

### Philosophy
**Apply business rules, remove problematic data, enrich with reference data**

### What Happens in Silver
- ✅ Remove rows with nulls in **critical** fields (e.g., permit_number, issue_date)
- ✅ Filter outliers based on **business logic** (e.g., total_fee < $0 or > $10M)
- ✅ Deduplicate based on **unique identifiers**
- ✅ Validate coordinates (lat between 41.6-42.1, lon between -87.95 to -87.5)
- ✅ Enrich with reference data (community names, ZIP codes)
- ✅ Apply derived calculations

**Example Silver View:**
```sql
-- silver_data.permits_clean (Silver)
CREATE OR REPLACE VIEW `silver_data.permits_clean` AS
SELECT
  permit_,
  issue_date,
  total_fee,
  latitude,
  longitude,
  community_area,
  -- Add data quality flags
  CASE
    WHEN latitude IS NULL OR longitude IS NULL THEN 'missing_coordinates'
    WHEN latitude NOT BETWEEN 41.6 AND 42.1 THEN 'invalid_coordinates'
    WHEN total_fee < 0 THEN 'negative_fee'
    WHEN total_fee > 10000000 THEN 'extreme_fee'
    ELSE 'valid'
  END as data_quality_flag
FROM `raw_data.raw_building_permits`
WHERE 1=1
  -- Critical field validations (fail hard)
  AND permit_ IS NOT NULL
  AND issue_date IS NOT NULL
  AND issue_date >= '2020-01-01'
  -- Soft validations (flag but include)
  AND (
    latitude IS NULL OR
    (latitude BETWEEN 41.6 AND 42.1 AND longitude BETWEEN -87.95 AND -87.5)
  )
  AND (
    total_fee IS NULL OR
    (total_fee >= 0 AND total_fee <= 10000000)
  );
```

---

## 📊 Great Expectations - Two-Stage Approach

### Stage 1: Critical Validation (In Extractor, Before Bronze)

**Location:** Inside Go extractor code
**Purpose:** Fail fast for catastrophic issues
**When to Fail:** Only for issues that indicate the source is broken

**Go Extractor Validation:**
```go
package main

import (
    "fmt"
    "time"
)

type DataQualityCheck struct {
    Name          string
    Severity      string  // "CRITICAL", "WARNING", "INFO"
    Threshold     float64
    ActualValue   float64
    Passed        bool
}

func validateBeforeBronze(records []PermitRecord) ([]DataQualityCheck, error) {
    checks := []DataQualityCheck{}

    // Check 1: Zero records returned (CRITICAL)
    zeroRecords := DataQualityCheck{
        Name:        "non_zero_record_count",
        Severity:    "CRITICAL",
        Threshold:   1,
        ActualValue: float64(len(records)),
        Passed:      len(records) > 0,
    }
    checks = append(checks, zeroRecords)
    if !zeroRecords.Passed {
        return checks, fmt.Errorf("CRITICAL: Zero records returned from API")
    }

    // Check 2: Primary key presence (CRITICAL)
    nullPrimaryKeys := 0
    for _, r := range records {
        if r.PermitNumber == "" {
            nullPrimaryKeys++
        }
    }
    nullPKPct := float64(nullPrimaryKeys) / float64(len(records)) * 100

    pkCheck := DataQualityCheck{
        Name:        "permit_number_not_null",
        Severity:    "CRITICAL",
        Threshold:   5.0,  // Fail if >5% have null PKs
        ActualValue: nullPKPct,
        Passed:      nullPKPct <= 5.0,
    }
    checks = append(checks, pkCheck)
    if !pkCheck.Passed {
        return checks, fmt.Errorf("CRITICAL: %.2f%% of records missing permit_number", nullPKPct)
    }

    // Check 3: Date range sanity (CRITICAL)
    futureCount := 0
    for _, r := range records {
        if !r.IssueDate.IsZero() && r.IssueDate.After(time.Now().AddDate(1, 0, 0)) {
            futureCount++
        }
    }
    futurePct := float64(futureCount) / float64(len(records)) * 100

    dateCheck := DataQualityCheck{
        Name:        "issue_date_not_future",
        Severity:    "WARNING",  // Not critical, just document
        Threshold:   10.0,
        ActualValue: futurePct,
        Passed:      futurePct <= 10.0,
    }
    checks = append(checks, dateCheck)
    // Don't fail for this, just log

    // Check 4: Coordinate presence (INFO only)
    nullCoords := 0
    for _, r := range records {
        if r.Latitude == 0 || r.Longitude == 0 {
            nullCoords++
        }
    }
    coordPct := float64(nullCoords) / float64(len(records)) * 100

    coordCheck := DataQualityCheck{
        Name:        "coordinates_present",
        Severity:    "INFO",
        Threshold:   20.0,
        ActualValue: coordPct,
        Passed:      coordPct <= 20.0,
    }
    checks = append(checks, coordCheck)
    // Don't fail, just document

    // All critical checks passed, load to Bronze
    return checks, nil
}

// Log quality checks to BigQuery for tracking
func logQualityChecks(checks []DataQualityCheck, extractionDate string) error {
    // Insert into reference_data.data_quality_log table
    // Track quality metrics over time
    return nil
}
```

**Decision Tree:**
```
Is API returning zero records?
  → YES: FAIL (don't load to Bronze)
  → NO: Continue

Are >50% of records missing primary key?
  → YES: FAIL (API broken)
  → NO: Continue

Are >90% of records missing required dates?
  → YES: FAIL (schema change)
  → NO: Continue

Some records have null coordinates?
  → YES: LOG as WARNING, load to Bronze anyway
  → NO: Continue

Some records have outlier fees?
  → YES: LOG as INFO, load to Bronze anyway
  → NO: Continue

→ Load ALL records to Bronze (including ones with warnings)
```

### Stage 2: Quality Documentation (After Bronze, Before Silver)

**Location:** BigQuery SQL scripts or dbt tests
**Purpose:** Document data quality, inform Silver transformations
**When to Run:** After each Bronze load, before creating Silver views

**Quality Check SQL:**
```sql
-- Create quality check results table
CREATE TABLE IF NOT EXISTS `reference_data.data_quality_checks` (
  check_date DATE,
  dataset_name STRING,
  check_name STRING,
  check_type STRING,  -- 'completeness', 'validity', 'consistency', 'uniqueness'
  expected_value FLOAT64,
  actual_value FLOAT64,
  passed BOOL,
  row_count INT64,
  failed_row_count INT64
);

-- Run quality checks on Bronze permits
INSERT INTO `reference_data.data_quality_checks`
WITH quality_checks AS (
  -- Check 1: Completeness - permit_number
  SELECT
    CURRENT_DATE() as check_date,
    'raw_building_permits' as dataset_name,
    'permit_number_not_null' as check_name,
    'completeness' as check_type,
    100.0 as expected_value,
    ROUND(COUNTIF(permit_ IS NOT NULL) / COUNT(*) * 100, 2) as actual_value,
    COUNTIF(permit_ IS NOT NULL) / COUNT(*) >= 0.95 as passed,
    COUNT(*) as row_count,
    COUNTIF(permit_ IS NULL) as failed_row_count
  FROM `raw_data.raw_building_permits`
  WHERE DATE(issue_date) = CURRENT_DATE() - 1

  UNION ALL

  -- Check 2: Completeness - coordinates
  SELECT
    CURRENT_DATE(),
    'raw_building_permits',
    'coordinates_present',
    'completeness',
    90.0,
    ROUND(COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL) / COUNT(*) * 100, 2),
    COUNTIF(latitude IS NOT NULL AND longitude IS NOT NULL) / COUNT(*) >= 0.80,
    COUNT(*),
    COUNTIF(latitude IS NULL OR longitude IS NULL)
  FROM `raw_data.raw_building_permits`
  WHERE DATE(issue_date) = CURRENT_DATE() - 1

  UNION ALL

  -- Check 3: Validity - coordinate bounds
  SELECT
    CURRENT_DATE(),
    'raw_building_permits',
    'coordinates_valid_range',
    'validity',
    95.0,
    ROUND(
      COUNTIF(
        latitude BETWEEN 41.6 AND 42.1 AND
        longitude BETWEEN -87.95 AND -87.5
      ) / COUNTIF(latitude IS NOT NULL) * 100,
      2
    ),
    COUNTIF(
      latitude BETWEEN 41.6 AND 42.1 AND
      longitude BETWEEN -87.95 AND -87.5
    ) / COUNTIF(latitude IS NOT NULL) >= 0.95,
    COUNTIF(latitude IS NOT NULL),
    COUNTIF(
      latitude IS NOT NULL AND (
        latitude NOT BETWEEN 41.6 AND 42.1 OR
        longitude NOT BETWEEN -87.95 AND -87.5
      )
    )
  FROM `raw_data.raw_building_permits`
  WHERE DATE(issue_date) = CURRENT_DATE() - 1

  UNION ALL

  -- Check 4: Validity - fee range
  SELECT
    CURRENT_DATE(),
    'raw_building_permits',
    'total_fee_reasonable',
    'validity',
    98.0,
    ROUND(
      COUNTIF(total_fee BETWEEN 0 AND 10000000) / COUNTIF(total_fee IS NOT NULL) * 100,
      2
    ),
    COUNTIF(total_fee BETWEEN 0 AND 10000000) / COUNTIF(total_fee IS NOT NULL) >= 0.95,
    COUNTIF(total_fee IS NOT NULL),
    COUNTIF(total_fee IS NOT NULL AND (total_fee < 0 OR total_fee > 10000000))
  FROM `raw_data.raw_building_permits`
  WHERE DATE(issue_date) = CURRENT_DATE() - 1

  UNION ALL

  -- Check 5: Uniqueness - duplicate permit numbers
  SELECT
    CURRENT_DATE(),
    'raw_building_permits',
    'permit_number_unique',
    'uniqueness',
    100.0,
    ROUND((COUNT(*) - COUNT(*) + COUNT(DISTINCT permit_)) / COUNT(*) * 100, 2),
    COUNT(DISTINCT permit_) = COUNT(*),
    COUNT(*),
    COUNT(*) - COUNT(DISTINCT permit_)
  FROM `raw_data.raw_building_permits`
  WHERE DATE(issue_date) = CURRENT_DATE() - 1
)
SELECT * FROM quality_checks;

-- View quality check results
SELECT
  check_date,
  dataset_name,
  check_name,
  check_type,
  expected_value,
  actual_value,
  passed,
  row_count,
  failed_row_count,
  CASE
    WHEN passed THEN '✅ PASS'
    ELSE '❌ FAIL'
  END as status
FROM `reference_data.data_quality_checks`
WHERE check_date >= CURRENT_DATE() - 7
ORDER BY check_date DESC, dataset_name, check_type;
```

---

## 🥇 Gold Layer - Aggregated, Business-Ready

### Philosophy
**Aggregated, denormalized tables optimized for dashboards and analysis**

**Example Gold Table:**
```sql
-- gold_data.permits_monthly_summary
CREATE TABLE `gold_data.permits_monthly_summary` AS
SELECT
  EXTRACT(YEAR FROM issue_date) as year,
  EXTRACT(MONTH FROM issue_date) as month,
  community_area_name,
  COUNT(*) as permit_count,
  SUM(total_fee) as total_fees,
  AVG(total_fee) as avg_fee,
  COUNT(DISTINCT permit_type) as unique_permit_types
FROM `silver_data.permits_clean`
WHERE data_quality_flag = 'valid'  -- Only use clean data
GROUP BY year, month, community_area_name;
```

---

## 🛠️ Implementation Checklist

### Phase 1: Bronze (Current State) ✅
- [x] Raw data loaded as-is to BigQuery
- [x] No filtering or transformations
- [x] Partitioned by date for performance

### Phase 2: Critical Validations (In Progress)
- [ ] Add validation logic to Go extractors
- [ ] Fail fast for catastrophic issues only
- [ ] Log quality metrics to BigQuery

### Phase 3: Quality Documentation (Next)
- [ ] Create `data_quality_checks` table
- [ ] Write SQL quality check scripts
- [ ] Schedule daily quality reports
- [ ] Create data quality dashboard

### Phase 4: Silver Layer (Next)
- [ ] Create clean views with business rules
- [ ] Document filtering criteria
- [ ] Add data quality flags
- [ ] Enrich with reference data

### Phase 5: Gold Layer (Future)
- [ ] Create aggregated tables
- [ ] Optimize for dashboard queries
- [ ] Schedule incremental refreshes

---

## 📈 Data Quality Metrics to Track

### Completeness
- % of records with non-null primary keys
- % of records with coordinates
- % of records with required fields populated

### Validity
- % of coordinates within Chicago bounds
- % of fees within reasonable range ($0 - $10M)
- % of dates within valid range (not future)

### Consistency
- % of community_area matching verified geography
- % of ZIP codes matching boundary lookups

### Uniqueness
- % of duplicate permit numbers
- % of duplicate trip IDs

### Timeliness
- Hours since last successful extraction
- Days of data lag vs source API

---

## 🎯 Summary: Where to Check What

| Layer | What to Check | When to Fail | Tools |
|-------|---------------|--------------|-------|
| **Extractor → Bronze** | Catastrophic failures (zero records, schema change, >50% nulls) | Always fail | Go validation code |
| **Bronze** | Store everything | Never fail | N/A - just load |
| **Bronze → Silver** | Quality documentation (null %, outliers, consistency) | Never fail, document only | SQL checks, dbt tests |
| **Silver** | Apply business rules (remove nulls, filter outliers) | N/A - filtering, not failing | SQL WHERE clauses |
| **Gold** | Use clean Silver data | N/A - aggregation | SQL aggregations |

---

**Key Principle:** Bronze = Raw Truth (keep everything), Silver = Clean Truth (apply rules), Gold = Aggregate Truth (optimize for queries)

**Last Updated:** November 6, 2025
