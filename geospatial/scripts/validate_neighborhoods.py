#!/usr/bin/env python3
"""
Validate Chicago Neighborhoods GeoJSON file

Comprehensive validation to check for missing or malformed geometries
"""

import json
from pathlib import Path

def validate_neighborhoods():
    filepath = "/Users/albin/Downloads/Geographical Reference Files/Neighborhoods_2012b_20251030.geojson"

    print("="*70)
    print("NEIGHBORHOODS GEOMETRY VALIDATION")
    print("="*70)
    print(f"\nFile: {Path(filepath).name}\n")

    # Load file
    with open(filepath, 'r') as f:
        data = json.load(f)

    features = data.get('features', [])
    print(f"Total neighborhoods: {len(features)}\n")

    # Validation counters
    valid_count = 0
    invalid_geometries = []
    null_geometries = []
    empty_coordinates = []
    malformed_features = []

    # Validate each feature
    for i, feature in enumerate(features):
        try:
            # Get neighborhood name
            pri_neigh = feature.get('properties', {}).get('pri_neigh', f'Unknown_{i}')
            sec_neigh = feature.get('properties', {}).get('sec_neigh', '')

            # Check geometry exists
            if 'geometry' not in feature:
                malformed_features.append((i, pri_neigh, "Missing 'geometry' field"))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Missing 'geometry' field")
                continue

            geometry = feature['geometry']

            # Check if geometry is null
            if geometry is None:
                null_geometries.append((i, pri_neigh))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Geometry is NULL")
                continue

            # Check geometry type
            geom_type = geometry.get('type', 'Unknown')

            # Check coordinates
            if 'coordinates' not in geometry:
                malformed_features.append((i, pri_neigh, "Missing 'coordinates' field"))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Missing 'coordinates' field")
                continue

            coordinates = geometry['coordinates']

            # Check if coordinates are null or empty
            if coordinates is None:
                empty_coordinates.append((i, pri_neigh, "Coordinates are NULL"))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Coordinates are NULL")
                continue

            if not isinstance(coordinates, list):
                malformed_features.append((i, pri_neigh, f"Coordinates are {type(coordinates).__name__}, not list"))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Coordinates are not a list")
                continue

            if len(coordinates) == 0:
                empty_coordinates.append((i, pri_neigh, "Coordinates array is empty"))
                print(f"❌ [{i:2d}] {pri_neigh:40s} - Coordinates array is EMPTY")
                continue

            # Count coordinate points
            if geom_type == 'MultiPolygon':
                try:
                    point_count = sum(len(ring) for polygon in coordinates for ring in polygon)
                    polygon_count = len(coordinates)
                except (TypeError, ValueError) as e:
                    malformed_features.append((i, pri_neigh, f"Malformed MultiPolygon: {str(e)}"))
                    print(f"❌ [{i:2d}] {pri_neigh:40s} - Malformed MultiPolygon structure")
                    continue
            elif geom_type == 'Polygon':
                try:
                    point_count = sum(len(ring) for ring in coordinates)
                    polygon_count = 1
                except (TypeError, ValueError) as e:
                    malformed_features.append((i, pri_neigh, f"Malformed Polygon: {str(e)}"))
                    print(f"❌ [{i:2d}] {pri_neigh:40s} - Malformed Polygon structure")
                    continue
            else:
                point_count = 0
                polygon_count = 0

            # Valid geometry
            valid_count += 1
            sec_display = f" / {sec_neigh}" if sec_neigh else ""
            print(f"✅ [{i:2d}] {pri_neigh:40s}{sec_display:30s} - {geom_type:15s} - {polygon_count} polygon(s), {point_count:5d} points")

        except Exception as e:
            malformed_features.append((i, pri_neigh if 'pri_neigh' in locals() else 'Unknown', f"Exception: {str(e)}"))
            print(f"❌ [{i:2d}] ERROR processing feature: {str(e)}")

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(f"Total neighborhoods:      {len(features)}")
    print(f"✅ Valid geometries:      {valid_count}")
    print(f"❌ Null geometries:       {len(null_geometries)}")
    print(f"❌ Empty coordinates:     {len(empty_coordinates)}")
    print(f"❌ Malformed features:    {len(malformed_features)}")
    print(f"❌ Total invalid:         {len(null_geometries) + len(empty_coordinates) + len(malformed_features)}")
    print("="*70)

    # Detailed error listing
    if null_geometries or empty_coordinates or malformed_features:
        print("\n" + "="*70)
        print("DETAILED ERROR LIST")
        print("="*70)

        if null_geometries:
            print(f"\n🚫 NULL GEOMETRIES ({len(null_geometries)}):")
            for idx, name in null_geometries:
                print(f"   [{idx:2d}] {name}")

        if empty_coordinates:
            print(f"\n🚫 EMPTY COORDINATES ({len(empty_coordinates)}):")
            for idx, name, reason in empty_coordinates:
                print(f"   [{idx:2d}] {name}: {reason}")

        if malformed_features:
            print(f"\n🚫 MALFORMED FEATURES ({len(malformed_features)}):")
            for idx, name, reason in malformed_features:
                print(f"   [{idx:2d}] {name}: {reason}")

        print("\n" + "="*70)

    # Final verdict
    print("\nFINAL VERDICT:")
    print("="*70)

    if valid_count == len(features):
        print(f"✅ ALL {len(features)} neighborhoods have VALID geometries!")
        print("   The file is COMPLETE and READY TO USE.")
        print("\n   CSV viewing issue is due to format limitations, NOT missing data.")
    else:
        invalid_count = len(features) - valid_count
        print(f"⚠️  {invalid_count} out of {len(features)} neighborhoods have INVALID geometries.")
        print(f"   These may need to be fixed or obtained from another source.")

    print("="*70 + "\n")

    return {
        'total': len(features),
        'valid': valid_count,
        'null_geometries': null_geometries,
        'empty_coordinates': empty_coordinates,
        'malformed_features': malformed_features
    }

if __name__ == "__main__":
    validate_neighborhoods()
