#!/usr/bin/env python3
"""
Simple GeoJSON Geometry Viewer

Visualize Chicago community area boundaries properly
(instead of trying to view them in CSV which doesn't work)

Usage:
    python view_geometries.py [--file PATH] [--areas AREA1,AREA2,...]

Examples:
    # View all areas
    python view_geometries.py

    # View specific areas
    python view_geometries.py --areas "NORWOOD PARK,FOREST GLEN,OHARE,NEAR SOUTH SIDE"

    # View different file
    python view_geometries.py --file ~/Downloads/export.geojson

Requirements:
    pip install geopandas matplotlib
"""

import argparse
import geopandas as gpd
import matplotlib.pyplot as plt
from pathlib import Path

def view_boundaries(filepath: str, filter_areas: list = None):
    """Load and visualize GeoJSON boundaries."""
    print(f"Loading: {filepath}\n")

    # Load GeoJSON
    gdf = gpd.read_file(filepath)

    # Identify community name column
    if 'community' in gdf.columns:
        name_col = 'community'
    elif 'name' in gdf.columns:
        name_col = 'name'
    else:
        name_col = None

    # Filter if requested
    if filter_areas and name_col:
        filter_upper = [a.upper() for a in filter_areas]
        gdf = gdf[gdf[name_col].str.upper().isin(filter_upper)]
        print(f"Filtered to {len(gdf)} areas: {', '.join(filter_areas)}\n")

    # Display summary
    print(f"Total features: {len(gdf)}")
    print(f"CRS: {gdf.crs}")
    print(f"Bounds: {gdf.total_bounds}")
    print(f"\nColumns: {', '.join(gdf.columns)}\n")

    # Show data
    if name_col:
        print("Community Areas:")
        for idx, row in gdf.iterrows():
            geom_type = row.geometry.geom_type
            area_km2 = row.geometry.area * 111 * 111  # Rough conversion
            print(f"  - {row[name_col]:30s} ({geom_type:15s}, {area_km2:6.2f} km²)")
    else:
        print(gdf.head())

    # Plot
    print("\nGenerating plot...")
    fig, ax = plt.subplots(figsize=(12, 10))

    # Plot geometries
    gdf.plot(ax=ax, color='lightblue', edgecolor='black', linewidth=0.5, alpha=0.7)

    # Add labels if filtering specific areas
    if filter_areas and name_col and len(gdf) <= 10:
        for idx, row in gdf.iterrows():
            centroid = row.geometry.centroid
            ax.annotate(
                row[name_col],
                xy=(centroid.x, centroid.y),
                ha='center',
                fontsize=8,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.7)
            )

    ax.set_title(f"Chicago Community Areas ({len(gdf)} areas)", fontsize=16, fontweight='bold')
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.show()

    print("\n✅ Visualization complete!")

def main():
    parser = argparse.ArgumentParser(description="View GeoJSON community area boundaries")
    parser.add_argument(
        '--file',
        default='/Users/albin/Downloads/Geographical Reference Files/Boundaries_-_Community_Areas_20251030.geojson',
        help='Path to GeoJSON file'
    )
    parser.add_argument(
        '--areas',
        help='Comma-separated list of area names to filter (e.g., "NORWOOD PARK,FOREST GLEN")'
    )

    args = parser.parse_args()

    # Parse filter areas
    filter_areas = None
    if args.areas:
        filter_areas = [a.strip() for a in args.areas.split(',')]

    # View
    view_boundaries(args.file, filter_areas)

if __name__ == "__main__":
    main()
