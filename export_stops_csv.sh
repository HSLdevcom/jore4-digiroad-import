#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker_start

# Export csv file to output directory.
OUTPUT_FILENAME="digiroad_stops_${DIGIROAD_IRROTUS_NRO}.csv"

mkdir -p "$WORK_DIR"/csv

docker_exec "$CURRUSER" "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_stops_as_csv.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD -o /tmp/csv/$OUTPUT_FILENAME"

# Stop Docker container.
docker_stop
