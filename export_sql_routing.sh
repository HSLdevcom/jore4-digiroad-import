#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER

# Wait for PostgreSQL to start.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres $DOCKER_IMAGE sh -c "$PG_WAIT"

SQL_OUTPUT="digiroad_r_routing_$(date "+%Y-%m-%d").sql"
OUTPUT_TABLES="dr_linkki dr_linkki_vertices_pgr dr_pysakki"
OUTPUT_TABLE_OPTIONS="`echo ${OUTPUT_TABLES[@]} | sed \"s/dr_/-t ${DB_ROUTING_SCHEMA_NAME}.dr_/g\"`"

# Export sql file.
docker run -it --rm --link "${DOCKER_CONTAINER}":postgres -v ${WORK_DIR}/pgdump/:/tmp/pgdump $DOCKER_IMAGE \
  sh -c "$PG_DUMP --no-owner -f /tmp/pgdump/${SQL_OUTPUT} $OUTPUT_TABLE_OPTIONS"

# Stop Docker container.
docker stop $DOCKER_CONTAINER
