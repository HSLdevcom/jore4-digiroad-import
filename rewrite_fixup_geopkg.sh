#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")" || exit; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain required database tables to be exported.
$DOCKER_START

# Wait for PostgreSQL server to be ready.
$DOCKER_EXEC_POSTGRES "exec $PG_WAIT"

OGR2OGR="exec ogr2ogr -f GPKG -overwrite /tmp/gpkg/fixup.gpkg $OGR2OGR_PG_REF"

$DOCKER_EXEC_HOSTUSER "$OGR2OGR -nlt LINESTRINGZM -nln add_links -dim XYZM -sql \"SELECT * FROM fix_layer_link\""
$DOCKER_EXEC_HOSTUSER "$OGR2OGR -nln add_stop_points -sql \"SELECT * FROM fix_layer_stop_point\""
$DOCKER_EXEC_HOSTUSER "$OGR2OGR -nlt LINESTRINGZM -nln remove_links -dim XYZM -sql \"SELECT * FROM fix_layer_link_exclusion_geometry\""

# Stop Docker container.
$DOCKER_STOP
