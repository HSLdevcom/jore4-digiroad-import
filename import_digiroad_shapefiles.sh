#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

AREA="UUSIMAA"

SHP_URL="https://ava.vaylapilvi.fi/ava/Tie/Digiroad/Aineistojulkaisut/latest/Maakuntajako_digiroad_R/${AREA}.zip"

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/${AREA}_R.zip"

# Load zip file containing Digiroad shapefiles if it does not exist.
if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
  mkdir -p "$DOWNLOAD_TARGET_DIR"
  curl -Lo "$DOWNLOAD_TARGET_FILE" "$SHP_URL"
fi

SUB_AREAS="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"
SHP_FILE_DIR="${WORK_DIR}/shp/${AREA}"

for SUB_AREA in $SUB_AREAS; do
  mkdir -p "${SHP_FILE_DIR}/${SUB_AREA}"
  # Extract all shapefiles within sub-area.
  unzip -u "$DOWNLOAD_TARGET_FILE" "$SUB_AREA"/* -d "$SHP_FILE_DIR"
done

# Extract shapefile for public transport stops (common to all sub-areas of Uusimaa).
unzip -u "$DOWNLOAD_TARGET_FILE" PYSAKIT/PYSAKIT.zip -d "${DOWNLOAD_TARGET_DIR}/${AREA}"
unzip -u "${DOWNLOAD_TARGET_DIR}/${AREA}/PYSAKIT/PYSAKIT.zip" -d "$SHP_FILE_DIR"
rm -fr "${DOWNLOAD_TARGET_DIR:?}/${AREA}"

# Extract general Digiroad documents.
unzip -u "$DOWNLOAD_TARGET_FILE" Dokumentit/* -d "$DOWNLOAD_TARGET_DIR"

# Remove possibly running/existing Docker container.
docker kill "$DOCKER_CONTAINER_NAME" &> /dev/null || true
docker rm -v "$DOCKER_CONTAINER_NAME" &> /dev/null || true

# Create directories that will be mounted to Docker container.
mkdir -p "$WORK_DIR"/csv
mkdir -p "$WORK_DIR"/mbtiles
mkdir -p "$WORK_DIR"/pgdump

# Create and start new Docker container. Mount all directories as volumes that
# are needed by various processing scripts.
docker run \
  --name "$DOCKER_CONTAINER_NAME" \
  -p 127.0.0.1:${DOCKER_CONTAINER_PORT}:5432 \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -v "$CWD"/fixup/digiroad:/tmp/gpkg \
  -v "$CWD"/sql:/tmp/sql \
  -v "$SHP_FILE_DIR":/tmp/shp \
  -v "$WORK_DIR"/csv:/tmp/csv \
  -v "$WORK_DIR"/mbtiles:/tmp/mbtiles \
  -v "$WORK_DIR"/pgdump:/tmp/pgdump \
  -d "$DOCKER_IMAGE"

# Wait for PostgreSQL server to be ready.
docker_exec postgres "exec $PG_WAIT"

# Create digiroad import schema into database.
docker_exec postgres "exec $PSQL -nt -c \"CREATE SCHEMA ${DB_SCHEMA_NAME_DIGIROAD};\""

SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W $SHP_ENCODING"

# Load only selected shapefiles into database.
SUB_AREA_SHP_TYPES="DR_LINKKI DR_KAANTYMISRAJOITUS"

for SUB_AREA_SHP_TYPE in $SUB_AREA_SHP_TYPES; do
  # Derive lowercase table name for shape type.
  TABLE_NAME="${DB_SCHEMA_NAME_DIGIROAD}.$(echo "$SUB_AREA_SHP_TYPE" | awk '{print tolower($0)}')"

  # Create database table for each shape type.
  docker_exec postgres "$SHP2PGSQL -p /tmp/shp/${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | exec $PSQL -v ON_ERROR_STOP=1 -q"

  # Populate database table from multiple shapefiles from sub areas.
  docker_exec postgres "for SUB_AREA in ${SUB_AREAS}; do $SHP2PGSQL -a /tmp/shp/\${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | exec $PSQL -v ON_ERROR_STOP=1; done"
done

# Import "add_links" and "remove_links" layers from GeoPackage fixup file if it exists.
if [ -f "$CWD"/fixup/digiroad/fixup.gpkg ]; then
  OGR2OGR="exec ogr2ogr -f PostgreSQL $OGR2OGR_PG_REF /tmp/gpkg/fixup.gpkg"

  docker_exec postgres "$OGR2OGR -nln fix_layer_link add_links"
  docker_exec postgres "$OGR2OGR -nln fix_layer_link_exclusion_geometry remove_links"
  docker_exec postgres "$OGR2OGR -nln fix_layer_stop_point add_stop_points"
fi

# Load DR_PYSAKKI shapefile into database.
docker_exec postgres "$SHP2PGSQL -c /tmp/shp/DR_PYSAKKI.shp ${DB_SCHEMA_NAME_DIGIROAD}.dr_pysakki | exec $PSQL -v ON_ERROR_STOP=1"

# Process road geometries and filtering properties in database.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_linkki.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Process stops and filter properties in database.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_pysakki.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Create SQL views combining Digiroad links and public transport stops with fixup layers from GeoPackage file.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/apply_fixup_layer.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Process turn restrictions and filter properties in database.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_kaantymisrajoitus.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Create separate schema for exporting data in MBTiles format.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/create_mbtiles_schema.sql -v source_schema=$DB_SCHEMA_NAME_DIGIROAD -v schema=$DB_SCHEMA_NAME_MBTILES"

# Stop Docker container.
docker_stop
