#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages. Print each command to stdout.
set -euxo pipefail

# Source common environment variables.
source "$(dirname "$0")/set_env_vars.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker start "$DOCKER_CONTAINER_NAME"

# Wait for PostgreSQL server to be ready.
$DOCKER_EXEC_POSTGRES "exec $PG_WAIT"

PGDUMP_OUTPUT="digiroad_r_$(date "+%Y-%m-%d").pgdump"
OUTPUT_TABLES="dr_linkki dr_pysakki dr_kaantymisrajoitus"
OUTPUT_TABLE_OPTIONS=$(echo "${OUTPUT_TABLES[@]}" | sed "s/dr_/-t ${DB_SCHEMA_NAME_DIGIROAD}.dr_/g")

mkdir -p "$WORK_DIR"/pgdump

# Export pg_dump file.
$DOCKER_EXEC_HOSTUSER "exec $PG_DUMP -Fc --clean -f /tmp/pgdump/$PGDUMP_OUTPUT $OUTPUT_TABLE_OPTIONS"

# Stop Docker container.
docker stop "$DOCKER_CONTAINER_NAME"
