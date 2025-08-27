#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(cd "$(dirname "$0")" || exit; pwd -P)/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
$DOCKER_START

# Wait for PostgreSQL server to be ready.
$DOCKER_EXEC_POSTGRES "exec $PG_WAIT"

# Export csv file to output directory.
OUTPUT_FILENAME="digiroad_stops.csv"

mkdir -p "$WORK_DIR"/csv

$DOCKER_EXEC_HOSTUSER "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_stops_as_csv.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD -o /tmp/csv/$OUTPUT_FILENAME"

# Stop Docker container.
$DOCKER_STOP
