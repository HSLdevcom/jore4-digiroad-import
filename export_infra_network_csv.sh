#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

usage() {
  echo "Usage: $(basename "$0") <MML_TRAM_IMPORT_DATE>"
  echo "  MML_TRAM_IMPORT_DATE must be in format YYYY-MM-DD"
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

MML_TRAM_IMPORT_DATE="$1"
if [[ ! "$MML_TRAM_IMPORT_DATE" =~ ^20[2-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "Invalid date: $MML_TRAM_IMPORT_DATE"
  usage
  exit 1
fi

# Start Docker container. The container is expected to exist and contain all the data to be exported.
docker_start

# Export CSV file to output directory.
OUTPUT_FILENAME="infra_network_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.csv"

mkdir -p "${WORK_DIR}/csv"

# Make sure infrastructure links are updated.
docker_exec postgres "exec $PSQL -nt -c \"REFRESH MATERIALIZED VIEW ${DB_SCHEMA_NAME_DIGIROAD}.dr_linkki_fixup;\""

docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/select_infra_links_as_csv.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD -o /tmp/csv/$OUTPUT_FILENAME"

# Stop Docker container.
docker_stop
