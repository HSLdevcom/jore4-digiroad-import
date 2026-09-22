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

TRAM_SQL_FILE="tram_infraLinks_${MML_TRAM_IMPORT_DATE}.sql"
SQL_INPUT_DIR="${CWD}/sql"

if [ ! -f "${SQL_INPUT_DIR}/${TRAM_SQL_FILE}" ]; then
  if [ ! -f "/tmp/${TRAM_SQL_FILE}" ]; then
    echo "Expected SQL file for processing tram links does not exist in /tmp or ${SQL_INPUT_DIR}: ${TRAM_SQL_FILE}"
    exit 1
  fi
  print_and_run_cmd mv "/tmp/${TRAM_SQL_FILE}" "${SQL_INPUT_DIR}/${TRAM_SQL_FILE}"
else
  echo "Using existing file: ${SQL_INPUT_DIR}/${TRAM_SQL_FILE}"
fi

# Start Docker container. The container is expected to exist and contain required database table to be exported.
print_and_run_cmd docker_start

# install pgcrypto extension for generating UUIDs
time docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'"

# import tram infra links
time print_and_run_cmd docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/${TRAM_SQL_FILE}"

# Stop Docker container.
 print_and_run_cmd docker_stop
