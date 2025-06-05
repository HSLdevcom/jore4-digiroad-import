#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Set working directory into a variable.
CWD="$(cd "$(dirname "$0")" || exit; pwd -P)"

# Source common environment variables.
source "$CWD"/set_env_vars.sh

# Start Docker container.
#
# The container is expected to exist and contain Digiroad schema with data
# populated from shapefiles.
docker start "$DOCKER_CONTAINER_NAME"

# Wait for PostgreSQL to start.
docker exec "$DOCKER_CONTAINER_NAME" sh -c "$PG_WAIT_LOCAL"

# Recreate fixup data in the import database.
docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/sql:/tmp/sql "$DOCKER_IMAGE" \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/fix_digiroad_links.sql -v schema=$DB_IMPORT_SCHEMA_NAME"

# Rewrite the GeoPackage file containing HSL's infrastructure network
# supplementing data.
source "$CWD"/rewrite_fixup_geopkg.sh

# Stop Docker container.
docker stop "$DOCKER_CONTAINER_NAME"
