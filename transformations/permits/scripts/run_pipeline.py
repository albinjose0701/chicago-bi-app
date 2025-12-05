#!/usr/bin/env python3
"""
Building Permits Data Pipeline - Orchestration Script
Purpose: Run incremental transformations from raw → bronze → silver → gold
Author: Claude Code
Created: November 21, 2025
"""

import os
import sys
import logging
from datetime import datetime
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError

# Configuration
PROJECT_ID = "chicago-bi-app-msds-432-476520"
LOCATION = "us-central1"

# SQL file paths
SQL_FILES = [
    "01_bronze_permits_incremental.sql",
    "02_silver_permits_incremental.sql",
    "03_gold_permits_aggregates.sql"
]

# Layer names for logging
LAYER_NAMES = ["BRONZE", "SILVER", "GOLD"]

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def read_sql_file(filepath):
    """Read SQL file and return content"""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        logger.info(f"✓ Read SQL file: {filepath}")
        return content
    except FileNotFoundError:
        logger.error(f"✗ SQL file not found: {filepath}")
        raise
    except Exception as e:
        logger.error(f"✗ Error reading SQL file {filepath}: {str(e)}")
        raise


def execute_sql(client, sql_content, layer_name):
    """Execute SQL query and return results"""
    try:
        logger.info(f"▶ Executing {layer_name} transformation...")

        # Split SQL into individual statements (separated by semicolons)
        statements = [s.strip() for s in sql_content.split(';') if s.strip() and not s.strip().startswith('--')]

        results = []
        for i, statement in enumerate(statements, 1):
            # Skip pure comment statements
            if statement.replace('\n', '').strip().startswith('--'):
                continue

            logger.info(f"  Running statement {i}/{len(statements)}...")

            try:
                query_job = client.query(statement, location=LOCATION)
                result = query_job.result()  # Wait for completion

                # If it's a SELECT query, get row count
                if statement.strip().upper().startswith('SELECT'):
                    row_count = result.total_rows
                    results.append({
                        'statement': i,
                        'rows': row_count
                    })
                    logger.info(f"    ✓ Statement {i} completed: {row_count} rows")
                else:
                    logger.info(f"    ✓ Statement {i} completed")

            except GoogleCloudError as e:
                logger.error(f"    ✗ Statement {i} failed: {str(e)}")
                raise

        logger.info(f"✓ {layer_name} transformation completed successfully")
        return results

    except Exception as e:
        logger.error(f"✗ {layer_name} transformation failed: {str(e)}")
        raise


def get_layer_stats(client, layer_name):
    """Get statistics for a data layer"""
    queries = {
        "BRONZE": """
            SELECT
                'BRONZE' as layer,
                COUNT(*) as total_records,
                COUNT(DISTINCT id) as unique_ids,
                MIN(issue_date) as oldest_permit,
                MAX(issue_date) as newest_permit,
                MAX(extracted_at) as last_update
            FROM `chicago-bi-app-msds-432-476520.bronze_data.bronze_building_permits`
        """,
        "SILVER": """
            SELECT
                'SILVER' as layer,
                COUNT(*) as total_records,
                COUNT(DISTINCT id) as unique_ids,
                COUNT(DISTINCT zip_code) as unique_zips,
                COUNTIF(zip_code IS NULL) as missing_zip,
                MIN(issue_date) as oldest_permit,
                MAX(issue_date) as newest_permit,
                MAX(enriched_at) as last_update
            FROM `chicago-bi-app-msds-432-476520.silver_data.silver_permits_enriched`
        """,
        "GOLD": """
            SELECT
                'GOLD - Permits ROI' as layer,
                COUNT(*) as total_zip_codes,
                SUM(total_permits) as total_permits,
                ROUND(SUM(total_permit_value), 2) as total_value,
                MAX(created_at) as last_update
            FROM `chicago-bi-app-msds-432-476520.gold_data.gold_permits_roi`

            UNION ALL

            SELECT
                'GOLD - Loan Targets' as layer,
                COUNT(*) as total_zip_codes,
                SUM(CAST(is_loan_eligible AS INT64)) as eligible_zips,
                ROUND(AVG(eligibility_index), 2) as avg_eligibility,
                MAX(created_at) as last_update
            FROM `chicago-bi-app-msds-432-476520.gold_data.gold_loan_targets`
        """
    }

    if layer_name not in queries:
        return None

    try:
        query_job = client.query(queries[layer_name], location=LOCATION)
        results = query_job.result()

        stats = []
        for row in results:
            stats.append(dict(row))

        return stats
    except Exception as e:
        logger.warning(f"Could not retrieve {layer_name} stats: {str(e)}")
        return None


def run_pipeline():
    """Main pipeline execution"""
    start_time = datetime.now()

    logger.info("=" * 80)
    logger.info("BUILDING PERMITS DATA PIPELINE - INCREMENTAL UPDATE")
    logger.info("=" * 80)
    logger.info(f"Start time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"Project: {PROJECT_ID}")
    logger.info(f"Location: {LOCATION}")
    logger.info("")

    # Initialize BigQuery client
    try:
        client = bigquery.Client(project=PROJECT_ID, location=LOCATION)
        logger.info("✓ BigQuery client initialized")
    except Exception as e:
        logger.error(f"✗ Failed to initialize BigQuery client: {str(e)}")
        return 1

    # Get script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Execute each transformation layer
    success_count = 0
    for i, (sql_file, layer_name) in enumerate(zip(SQL_FILES, LAYER_NAMES), 1):
        logger.info("")
        logger.info("-" * 80)
        logger.info(f"STEP {i}/{len(SQL_FILES)}: {layer_name} LAYER")
        logger.info("-" * 80)

        try:
            # Read SQL file
            sql_path = os.path.join(script_dir, sql_file)
            sql_content = read_sql_file(sql_path)

            # Execute transformation
            results = execute_sql(client, sql_content, layer_name)

            # Get layer statistics
            stats = get_layer_stats(client, layer_name)
            if stats:
                logger.info(f"\n📊 {layer_name} Layer Statistics:")
                for stat in stats:
                    for key, value in stat.items():
                        logger.info(f"  {key}: {value}")

            success_count += 1

        except Exception as e:
            logger.error(f"✗ Pipeline failed at {layer_name} layer")
            logger.error(f"Error: {str(e)}")

            # Calculate duration
            duration = datetime.now() - start_time
            logger.info("")
            logger.info("=" * 80)
            logger.info(f"PIPELINE FAILED after {duration}")
            logger.info(f"Successfully completed: {success_count}/{len(SQL_FILES)} layers")
            logger.info("=" * 80)
            return 1

    # Pipeline completed successfully
    end_time = datetime.now()
    duration = end_time - start_time

    logger.info("")
    logger.info("=" * 80)
    logger.info("✓ PIPELINE COMPLETED SUCCESSFULLY")
    logger.info("=" * 80)
    logger.info(f"End time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"Duration: {duration}")
    logger.info(f"Layers processed: {success_count}/{len(SQL_FILES)}")
    logger.info("")
    logger.info("Summary:")
    logger.info("  ✓ BRONZE: Incremental merge from raw")
    logger.info("  ✓ SILVER: Spatial enrichment (ZIP, neighborhood)")
    logger.info("  ✓ GOLD: Rebuilt aggregates (permits ROI, loan targets)")
    logger.info("")
    logger.info("Next steps:")
    logger.info("  - Verify data in BigQuery")
    logger.info("  - Refresh Dashboard 5 visualizations")
    logger.info("  - Check for any data quality issues")
    logger.info("=" * 80)

    return 0


if __name__ == "__main__":
    try:
        exit_code = run_pipeline()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n\nPipeline interrupted by user")
        sys.exit(130)
    except Exception as e:
        logger.error(f"\n\nUnexpected error: {str(e)}")
        sys.exit(1)
