#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker_start

# Export CSV file to output directory.
OUTPUT_FILENAME="infra_network_digiroad_${DIGIROAD_IRROTUS_NRO}.csv"

mkdir -p "${WORK_DIR}/csv"

# Make sure infrastructure links are updated.
docker_exec postgres "exec $PSQL -nt -c \"REFRESH MATERIALIZED VIEW ${DB_SCHEMA_NAME_DIGIROAD}.dr_linkki_fixup;\""

docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_infra_links_as_csv.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD -o /tmp/csv/$OUTPUT_FILENAME"

# Stop Docker container.
docker_stop
