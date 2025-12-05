# Archival Scripts

This directory contains scripts for exporting BigQuery data to GCS Coldline storage.

## Available Scripts

### `archive_quarter.sh`
- Export quarterly data to GCS Coldline (Parquet format)
- Reduces storage costs by 80% ($0.02/GB → $0.004/GB)
- Supports selective layer archival (bronze, silver, gold, or all)

**Usage:**
```bash
./archive_quarter.sh 2020-Q1 all        # Archive all layers
./archive_quarter.sh 2020-Q1 bronze     # Archive bronze only
```

## Workflow

1. **Complete your analysis** in BigQuery first
2. **Run archival script** to export to GCS Coldline
3. **Verify archive** using `gsutil ls` commands
4. **OPTIONAL**: Delete BigQuery partitions to save costs
5. **Restore if needed** using `bq load` command

## Cost Savings

Example for 20GB Q1 2020 data:
- Before archival: 20GB × $0.02/month = $0.40/month
- After archival: 20GB × $0.004/month = $0.08/month
- **Monthly savings: $0.32** (80% reduction)

## Important

⚠️ **Do NOT delete BigQuery partitions until archive is verified!**

⚠️ **Keep gold layer in BigQuery** for dashboard access

See `/docs/DATA_INGESTION_WORKFLOW.md` for complete documentation.
