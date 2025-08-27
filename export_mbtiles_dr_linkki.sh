#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")" || exit; pwd -P)/set_env_vars.sh"

DB_TABLE_NAME="dr_linkki"

MBTILES_MAX_ZOOM_LEVEL=16
MBTILES_LAYER_NAME=$DB_TABLE_NAME
MBTILES_DESCRIPTION="Digiroad road links"

MBTILES_OUTPUT_DIR="${WORK_DIR}/mbtiles"
SHP_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/shp_input"
GEOJSON_OUTPUT_DIR="${MBTILES_OUTPUT_DIR}/geojson_input"

mkdir -p "$SHP_OUTPUT_DIR"
mkdir -p "$GEOJSON_OUTPUT_DIR"

OUTPUT_FILE_BASENAME="${DB_TABLE_NAME}_$(date "+%Y-%m-%d")"

SHP_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.shp"
GEOJSON_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.geojson"
MBTILES_OUTPUT_FILE="${OUTPUT_FILE_BASENAME}.mbtiles"

# Start Docker container. The container is expected to exist and contain required database table to be exported.
$DOCKER_START

# Wait for PostgreSQL server to be ready.
$DOCKER_EXEC_POSTGRES "exec $PG_WAIT"

# Export pg_dump file from database.
time $DOCKER_EXEC_HOSTUSER "exec $PGSQL2SHP -f /tmp/mbtiles/shp_input/${SHP_OUTPUT_FILE} ${DB_NAME} ${DB_SCHEMA_NAME_MBTILES}.${DB_TABLE_NAME}"

# Convert from Shapefile to GeoJSON.

rm -f "${GEOJSON_OUTPUT_DIR}/$GEOJSON_OUTPUT_FILE" || true
time $DOCKER_EXEC_HOSTUSER \
  "exec ogr2ogr --config SHAPE_ENCODING $SHP_ENCODING -f GeoJSON -lco COORDINATE_PRECISION=7 /tmp/mbtiles/geojson_input/$GEOJSON_OUTPUT_FILE /tmp/mbtiles/shp_input/$SHP_OUTPUT_FILE"

# Convert from GeoJSON to MBTiles.

rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}" || true
rm -f "${MBTILES_OUTPUT_DIR}/${MBTILES_OUTPUT_FILE}-journal" || true
$DOCKER_EXEC_HOSTUSER "tippecanoe /tmp/mbtiles/geojson_input/$GEOJSON_OUTPUT_FILE -o /tmp/$MBTILES_OUTPUT_FILE -z$MBTILES_MAX_ZOOM_LEVEL -X -l $MBTILES_LAYER_NAME -n \"$MBTILES_DESCRIPTION\" -f && exec mv /tmp/$MBTILES_OUTPUT_FILE /tmp/mbtiles/$MBTILES_OUTPUT_FILE"

# Stop Docker container.
$DOCKER_STOP
