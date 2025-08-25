#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")" || exit; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain required database tables to be exported.
docker start "$DOCKER_CONTAINER_NAME"

# Wait for PostgreSQL server to be ready.
docker exec "$DOCKER_CONTAINER_NAME" sh -c "$PG_WAIT"

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR2OGR_PG_REF -nlt LINESTRINGZM -nln add_links -dim XYZM -sql \"SELECT * FROM fix_layer_link\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR2OGR_PG_REF -nln add_stop_points -sql \"SELECT * FROM fix_layer_stop_point\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/fixup/digiroad:/tmp/gpkg "$DOCKER_IMAGE" \
  sh -c "ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR2OGR_PG_REF -nlt LINESTRINGZM -nln remove_links -dim XYZM -sql \"SELECT * FROM fix_layer_link_exclusion_geometry\""

# Stop Docker container.
docker stop "$DOCKER_CONTAINER_NAME"
