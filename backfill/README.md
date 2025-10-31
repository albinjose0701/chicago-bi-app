# Backfill Scripts

This directory contains scripts for historical data ingestion.

## Available Scripts

### `quarterly_backfill_q1_2020.sh`
- Ingest Q1 2020 (January 1 - March 31, 2020)
- Creates 90 daily partitions
- Cost: ~$1.50 one-time
- Time: ~45 minutes per dataset

**Usage:**
```bash
./quarterly_backfill_q1_2020.sh all        # All datasets
./quarterly_backfill_q1_2020.sh taxi       # Taxi only
```

### `monthly_backfill.sh`
- Flexible monthly ingestion for any month
- Creates 28-31 daily partitions
- Cost: ~$0.40-0.60 per month
- Time: ~15 minutes per dataset

**Usage:**
```bash
./monthly_backfill.sh 2020-01 all     # January 2020
./monthly_backfill.sh 2020-02 taxi    # February 2020 taxi only
./monthly_backfill.sh 2020-03         # March 2020 all datasets
```

## Quick Start

1. Make sure you've deployed the Cloud Run extractors first
2. Run the appropriate backfill script
3. Check the generated log file for results
4. Verify data in BigQuery

See `/docs/DATA_INGESTION_WORKFLOW.md` for complete documentation.
