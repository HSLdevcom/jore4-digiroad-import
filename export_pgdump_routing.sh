#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres $DOCKER_IMAGE sh -c "$PG_WAIT"

PGDUMP_OUTPUT="digiroad_r_routing_$(date "+%Y-%m-%d").pgdump"

# Export pg_dump file.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${WORK_DIR}/pgdump/:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "$PG_DUMP -Fc --clean -f /tmp/pgdump/${PGDUMP_OUTPUT} --schema=${DB_ROUTING_SCHEMA_NAME} --no-owner"

# Stop Docker container.
docker stop $DOCKER_CONTAINER