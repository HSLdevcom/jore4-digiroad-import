#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

DB_TABLE_NAME="tram_links"

usage() {
  echo "Usage: $(basename "$0") <MML_TRAM_IMPORT_DATE>"
  echo "  MML_TRAM_IMPORT_DATE must be in format YYYY-MM-DD"
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

MML_TRAM_IMPORT_DATE="$1"
if [[ ! "$MML_TRAM_IMPORT_DATE" =~ ^20[2-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "Invalid date: $MML_TRAM_IMPORT_DATE"
  usage
  exit 1
fi

MBTILES_MAX_ZOOM_LEVEL=18
MBTILES_LAYER_NAME=$DB_TABLE_NAME
MBTILES_DESCRIPTION="Tram track links"

MBTILES_OUTPUT_DIR="${WORK_DIR}/mbtiles"
GEOJSON_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/geojson_input"
SQL_INPUT_DIR="${CWD}/sql"

print_and_run_cmd mkdir -p "$GEOJSON_OUTPUT_DIR"
print_and_run_cmd mkdir -p "$SQL_INPUT_DIR"
print_and_run_cmd mkdir -p "${WORK_DIR}/shp"

OUTPUT_FILE_BASENAME="${DB_TABLE_NAME}_${MML_TRAM_IMPORT_DATE}_zoom-${MBTILES_MAX_ZOOM_LEVEL}_$(date "+%Y-%m-%d")"

GEOJSON_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.geojson"
MBTILES_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.mbtiles"

# Start Docker container. The container is expected to exist and contain required database table to be exported.
print_and_run_cmd docker_start

# Export filtered links directly from PostGIS to GeoJSON.
rm -f "${GEOJSON_OUTPUT_DIR}/$GEOJSON_OUTPUT_FILE"
time docker_exec "$CURRUSER" \
  "exec ogr2ogr -f GeoJSON -lco COORDINATE_PRECISION=7 /tmp/mbtiles/geojson_input/$GEOJSON_OUTPUT_FILE \
  \"PG:host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USERNAME \" \
  -sql \"SELECT \
      infrastructure_link_id::text AS id, \
      external_link_id AS link_id,\
      ST_Force2D(shape::geometry) AS geom \
    FROM infrastructure_network.infrastructure_link \
    WHERE external_link_source = 'hsl_tram'\" \
  -nln $MBTILES_LAYER_NAME"

# Convert from GeoJSON to MBTiles.
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}"
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}-journal"
time docker_exec "$CURRUSER" \
  "tippecanoe /tmp/mbtiles/geojson_input/$GEOJSON_OUTPUT_FILE -o /tmp/$MBTILES_OUTPUT_FILE -z$MBTILES_MAX_ZOOM_LEVEL -X -l $MBTILES_LAYER_NAME -n \"$MBTILES_DESCRIPTION\" -f && exec mv /tmp/$MBTILES_OUTPUT_FILE /tmp/mbtiles/$MBTILES_OUTPUT_FILE"

# Stop Docker container.
 print_and_run_cmd docker_stop
