#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER}" sh -c "$PG_WAIT_LOCAL"

PGDUMP_OUTPUT="digiroad_r_routing_$(date "+%Y-%m-%d").pgdump"
OUTPUT_TABLES="dr_linkki dr_linkki_vertices_pgr dr_pysakki"
OUTPUT_TABLE_OPTIONS="`echo ${OUTPUT_TABLES[@]} | sed \"s/dr_/-t ${DB_ROUTING_SCHEMA_NAME}.dr_/g\"`"

# Export pg_dump file.
docker run --rm --link "${DOCKER_CONTAINER}":postgres -v ${WORK_DIR}/pgdump/:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "$PG_DUMP -Fc --clean -f /tmp/pgdump/${PGDUMP_OUTPUT} $OUTPUT_TABLE_OPTIONS"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
