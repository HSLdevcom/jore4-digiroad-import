#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

OGR_PG_SRC="PG:\"host=\$POSTGRES_PORT_5432_TCP_ADDR port=\$POSTGRES_PORT_5432_TCP_PORT user=digiroad dbname=$DB_NAME schemas=${DB_IMPORT_SCHEMA_NAME}\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR_PG_SRC -nlt LINESTRINGZM -nln add_links -dim XYZM -sql \"SELECT * FROM fix_layer_link\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR_PG_SRC -nln add_stop_points -sql \"SELECT * FROM fix_layer_stop_point\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR_PG_SRC -nlt LINESTRINGZM -nln remove_links -dim XYZM -sql \"SELECT * FROM fix_layer_link_exclusion_geometry\""
