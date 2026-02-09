#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

DB_TABLE_NAME="tram_links"

MML_TRAM_IMPORT_DATE="2026-01-28"

MBTILES_MAX_ZOOM_LEVEL=17
MBTILES_LAYER_NAME=$DB_TABLE_NAME
MBTILES_DESCRIPTION="Tram track links"

MBTILES_OUTPUT_DIR="${WORK_DIR}/mbtiles"
GEOJSON_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/geojson_input"
SQL_INPUT_DIR="${CWD}/sql"

print_and_run_cmd mkdir -p "$GEOJSON_OUTPUT_DIR"
print_and_run_cmd mkdir -p "$SQL_INPUT_DIR"
print_and_run_cmd mkdir -p "${WORK_DIR}/shp"

OUTPUT_FILE_BASENAME="${DB_TABLE_NAME}_${MML_TRAM_IMPORT_DATE}_$(date "+%Y-%m-%d")"

GEOJSON_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.geojson"
MBTILES_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.mbtiles"

if [ ! -f "${SQL_INPUT_DIR}/tram_infraLinks.sql" ]; then
  if [ ! -f "/tmp/tram_infraLinks.sql" ]; then
    echo "Expected SQL file for processing tram links does not exist: /tmp/tram_infraLinks.sql"
    exit 1
  fi
  print_and_run_cmd mv "/tmp/tram_infraLinks.sql" "${SQL_INPUT_DIR}/tram_infraLinks.sql"
else
  echo "Using existing file: ${SQL_INPUT_DIR}/tram_infraLinks.sql"
fi

print_and_run_cmd docker_kill
print_and_run_cmd docker_run "${WORK_DIR}/shp"

# install pgcrypto extension for generating UUIDs
time docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'"

# import tram infra links
time print_and_run_cmd docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/tram_infraLinks.sql"

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
    WHERE external_link_source = 'temp_hsl_tram'\" \
  -nln $MBTILES_LAYER_NAME"

# Convert from GeoJSON to MBTiles.
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}"
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}-journal"
time docker_exec "$CURRUSER" \
  "tippecanoe /tmp/mbtiles/geojson_input/$GEOJSON_OUTPUT_FILE -o /tmp/$MBTILES_OUTPUT_FILE -z$MBTILES_MAX_ZOOM_LEVEL -X -l $MBTILES_LAYER_NAME -n \"$MBTILES_DESCRIPTION\" -f && exec mv /tmp/$MBTILES_OUTPUT_FILE /tmp/mbtiles/$MBTILES_OUTPUT_FILE"

# Stop Docker container.
 print_and_run_cmd docker_stop
