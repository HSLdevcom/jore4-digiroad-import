#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

# Start Docker container. The container is expected to exist and contain required database tables to be exported.
docker_start

# Wait for PostgreSQL server to be ready.
docker_exec postgres "exec $PG_WAIT"

OGR2OGR="exec ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR2OGR_PG_REF"

docker_exec "$CURRUSER" "$OGR2OGR -nlt LINESTRINGZM -nln add_links -dim XYZM -sql \"SELECT * FROM fix_layer_link\""
docker_exec "$CURRUSER" "$OGR2OGR -nln add_stop_points -sql \"SELECT * FROM fix_layer_stop_point\""
docker_exec "$CURRUSER" "$OGR2OGR -nlt LINESTRINGZM -nln remove_links -dim XYZM -sql \"SELECT * FROM fix_layer_link_exclusion_geometry\""

# Stop Docker container.
docker_stop
