#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start $DOCKER_CONTAINER_NAME

# Wait for PostgreSQL to start.
docker exec "${DOCKER_CONTAINER_NAME}" sh -c "$PG_WAIT_LOCAL"

# Export csv file to output directory.
OUTPUT_FILENAME="digiroad_stops.csv"
mkdir -p ${WORK_DIR}/csv
docker run --rm --link "${DOCKER_CONTAINER_NAME}":postgres -v ${CWD}/sql:/tmp/sql -v ${WORK_DIR}/csv:/tmp/csv ${DOCKER_IMAGE} \
  sh -c "$PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_stops_as_csv.sql -v schema=${DB_SCHEMA_NAME_DIGIROAD} -o /tmp/csv/${OUTPUT_FILENAME}"

# Stop Docker container.
docker stop $DOCKER_CONTAINER_NAME
