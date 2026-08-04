#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W $SHP_ENCODING"

AREA="UUSIMAA"

SHP_FILE_DIR="${WORK_DIR}/shp/${AREA}"

# Start the Docker container.
docker_run "$SHP_FILE_DIR"

# Import "add_links" and "remove_links" layers from GeoPackage fixup file if it exists.
if [ -f "$CWD"/fixup/digiroad/fixup.gpkg ]; then
  OGR2OGR="exec ogr2ogr -f PostgreSQL -lco SCHEMA=digiroad $OGR2OGR_PG_REF /tmp/gpkg/fixup.gpkg"

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

# HSL tram infrastructure links were imported in export_mbtiles_tram_links.sh.
# Transform tram links into the Digiroad schema (reproject to EPSG:3067).
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_tram_links.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Process turn restrictions and filter properties in database.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/transform_dr_kaantymisrajoitus.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Create separate schema for exporting data in MBTiles format.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/create_mbtiles_schema.sql -v source_schema=$DB_SCHEMA_NAME_DIGIROAD -v schema=$DB_SCHEMA_NAME_MBTILES"

# Stop Docker container.
docker_stop
