#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euo pipefail

# Source common environment variables.
source "$(dirname "$0")/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker_start

# Wait for PostgreSQL server to be ready.
docker_exec postgres "exec $PG_WAIT"

PGDUMP_OUTPUT="digiroad_r_$(date "+%Y-%m-%d").pgdump"
OUTPUT_TABLES="dr_linkki dr_pysakki dr_kaantymisrajoitus"
OUTPUT_TABLE_OPTIONS=$(echo "${OUTPUT_TABLES[@]}" | sed "s/dr_/-t ${DB_SCHEMA_NAME_DIGIROAD}.dr_/g")

mkdir -p "$WORK_DIR"/pgdump

# Export pg_dump file.
docker_exec "$CURRUSER" "exec $PG_DUMP -Fc --clean -f /tmp/pgdump/$PGDUMP_OUTPUT $OUTPUT_TABLE_OPTIONS"

# Stop Docker container.
docker_stop
