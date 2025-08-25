#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(dirname "$0")/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start "$DOCKER_CONTAINER_NAME"

# Wait for PostgreSQL to start.
docker exec "$DOCKER_CONTAINER_NAME" sh -c "$PG_WAIT_LOCAL"

# Export CSV file to output directory.
OUTPUT_FILENAME="infra_network_digiroad.csv"
OUTPUT_FOLDER="${WORK_DIR}/csv"

mkdir -p "$OUTPUT_FOLDER"

# Make sure infrastructure links are updated.
docker exec "$DOCKER_CONTAINER_NAME" sh -c \
  "$PSQL -nt -c \"REFRESH MATERIALIZED VIEW ${DB_SCHEMA_NAME_DIGIROAD}.dr_linkki_fixup;\""

docker run --rm --link "$DOCKER_CONTAINER_NAME":postgres -v "$CWD"/sql:/tmp/sql -v "$OUTPUT_FOLDER":/tmp/csv "$DOCKER_IMAGE" \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_infra_links_as_csv.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD -o /tmp/csv/$OUTPUT_FILENAME"

# Stop Docker container.
docker stop "$DOCKER_CONTAINER_NAME"
