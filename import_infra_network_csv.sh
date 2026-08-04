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

# Reading connection parameters
echo "Please fill in the connection parameters for the database to import the data to:"
read -p "Hostname (default: localhost): " PGHOSTNAME
PGHOSTNAME="${PGHOSTNAME:-localhost}"
read -p "Database name (default: jore4e2e): " PGDATABASE
PGDATABASE="${PGDATABASE:-jore4e2e}"
read -p "Port (default: 6432): " PGPORT
PGPORT="${PGPORT:-6432}"
read -p "Username (default: dbadmin): " PGUSERNAME
PGUSERNAME="${PGUSERNAME:-dbadmin}"
read -p "Password (default: adminpassword): " PGPASSWORD
PGPASSWORD="${PGPASSWORD:-adminpassword}"

# Import dump from csv file.
INPUT_FILENAME="infra_network_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.csv"
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
  -v ON_ERROR_STOP=1 -f "$CWD"/sql/import_infra_links_from_csv.sql -v csvfile="${WORK_DIR}/csv/${INPUT_FILENAME}"
