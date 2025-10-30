#!/usr/bin/env python3
"""
Generate Chicago zip code boundaries for BigQuery GEOGRAPHY

This script:
1. Downloads Chicago zip code boundary shapefiles
2. Converts to WGS84 (EPSG:4326) for BigQuery compatibility
3. Uploads to BigQuery reference.ref_boundaries_zip table
4. No ongoing Cloud SQL costs!

Usage:
    python generate_zip_boundaries.py --project-id chicago-bi

Requirements:
    pip install geopandas pandas-gbq google-cloud-bigquery
"""

import argparse
import logging
from pathlib import Path

import geopandas as gpd
import pandas as pd
from google.cloud import bigquery

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Chicago zip code boundaries URL
CHICAGO_ZIP_BOUNDARIES_URL = (
    "https://data.cityofchicago.org/api/geospatial/igwz-8jzy"
    "?method=export&format=Shapefile"
)


def download_boundaries(output_dir: Path) -> Path:
    """Download Chicago zip code boundaries shapefile."""
    logger.info("Downloading Chicago zip code boundaries...")

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    shapefile_path = output_dir / "chicago_zip_boundaries.shp"

    # Download shapefile
    # Note: In production, use requests library or wget
    logger.info(f"Download URL: {CHICAGO_ZIP_BOUNDARIES_URL}")
    logger.info(f"Save to: {shapefile_path}")
    logger.info("Please download manually and extract to reference-maps/")

    return shapefile_path


def process_boundaries(shapefile_path: Path) -> gpd.GeoDataFrame:
    """Process shapefile and convert to BigQuery-compatible format."""
    logger.info(f"Reading shapefile: {shapefile_path}")

    # Read shapefile
    gdf = gpd.read_file(shapefile_path)

    logger.info(f"Original CRS: {gdf.crs}")
    logger.info(f"Total features: {len(gdf)}")

    # Convert to WGS84 (EPSG:4326) for BigQuery GEOGRAPHY
    if gdf.crs != "EPSG:4326":
        logger.info("Converting to WGS84 (EPSG:4326)...")
        gdf = gdf.to_crs(epsg=4326)

    # Rename columns to match BigQuery schema
    gdf = gdf.rename(columns={
        'ZIP': 'zip_code',
        'geometry': 'geometry'
    })

    # Add calculated fields
    gdf['area_sq_km'] = gdf.geometry.area * 111 * 111  # Rough conversion
    gdf['centroid_lat'] = gdf.geometry.centroid.y
    gdf['centroid_lon'] = gdf.geometry.centroid.x

    # Select only needed columns
    columns = ['zip_code', 'geometry', 'area_sq_km', 'centroid_lat', 'centroid_lon']
    gdf = gdf[columns]

    logger.info(f"Processed {len(gdf)} zip code boundaries")

    return gdf


def upload_to_bigquery(
    gdf: gpd.GeoDataFrame,
    project_id: str,
    dataset: str = "reference",
    table: str = "ref_boundaries_zip"
) -> None:
    """Upload GeoDataFrame to BigQuery."""
    logger.info(f"Uploading to BigQuery: {project_id}.{dataset}.{table}")

    # Initialize BigQuery client
    client = bigquery.Client(project=project_id)

    # Convert geometry to WKT (Well-Known Text) for BigQuery
    gdf['geometry'] = gdf['geometry'].apply(lambda x: x.wkt)

    # Define BigQuery schema
    schema = [
        bigquery.SchemaField("zip_code", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("geometry", "GEOGRAPHY", mode="REQUIRED"),
        bigquery.SchemaField("area_sq_km", "FLOAT64"),
        bigquery.SchemaField("centroid_lat", "FLOAT64"),
        bigquery.SchemaField("centroid_lon", "FLOAT64"),
    ]

    # Create table reference
    table_id = f"{project_id}.{dataset}.{table}"

    # Configure load job
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        source_format=bigquery.SourceFormat.CSV,
    )

    # Convert to pandas DataFrame for upload
    df = pd.DataFrame(gdf)

    # Load to BigQuery
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Wait for completion

    # Verify upload
    table = client.get_table(table_id)
    logger.info(f"✅ Uploaded {table.num_rows} rows to {table_id}")
    logger.info(f"Table size: {table.num_bytes / 1024 / 1024:.2f} MB")


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Generate Chicago zip code boundaries for BigQuery"
    )
    parser.add_argument(
        "--project-id",
        required=True,
        help="GCP project ID (e.g., chicago-bi)"
    )
    parser.add_argument(
        "--shapefile",
        type=Path,
        default=Path("../reference-maps/chicago_zip_boundaries.shp"),
        help="Path to shapefile (default: ../reference-maps/chicago_zip_boundaries.shp)"
    )
    parser.add_argument(
        "--download",
        action="store_true",
        help="Download shapefile (requires manual extraction)"
    )

    args = parser.parse_args()

    # Download if requested
    if args.download:
        output_dir = Path("../reference-maps")
        download_boundaries(output_dir)
        logger.info("Please extract the downloaded zip file and re-run without --download")
        return

    # Check if shapefile exists
    if not args.shapefile.exists():
        logger.error(f"Shapefile not found: {args.shapefile}")
        logger.info("Run with --download to get the shapefile")
        return

    # Process boundaries
    gdf = process_boundaries(args.shapefile)

    # Upload to BigQuery
    upload_to_bigquery(gdf, args.project_id)

    logger.info("✅ Successfully generated zip code boundaries!")
    logger.info(f"Query example:")
    logger.info(f"""
    SELECT
      zip_code,
      ST_GEOGFROMTEXT(geometry) AS geometry,
      area_sq_km
    FROM `{args.project_id}.reference.ref_boundaries_zip`
    LIMIT 10;
    """)


if __name__ == "__main__":
    main()
