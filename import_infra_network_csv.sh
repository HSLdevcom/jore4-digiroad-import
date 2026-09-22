#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

usage() {
  echo "Usage: $(basename "$0") [--with-defaults] <MML_TRAM_IMPORT_DATE>"
  echo "  MML_TRAM_IMPORT_DATE must be in format YYYY-MM-DD"
  echo "  --with-defaults  use default connection parameters and answer yes to confirmations"
}

WITH_DEFAULTS=false
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--with-defaults" ]]; then
    WITH_DEFAULTS=true
  else
    ARGS+=("$arg")
  fi
done
set -- ${ARGS[@]+"${ARGS[@]}"}

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
ask PGHOSTNAME "Hostname (default: localhost): " localhost
ask PGDATABASE "Database name (default: jore4e2e): " jore4e2e
ask PGPORT "Port (default: 6432): " 6432
ask PGUSERNAME "Username (default: dbadmin): " dbadmin
ask PGPASSWORD "Password (default: adminpassword): " adminpassword

ask TRUNCATE_ALL_DATABASES "Truncate data in eligible tables in jore4e2e, stopdb, and timetablesdb on $PGHOSTNAME:$PGPORT? [y/N]: " n y
if [[ "$TRUNCATE_ALL_DATABASES" =~ ^[Yy]$ ]]; then
  docker_stop_service hasura
  docker_stop_service tiamat
#  docker rm -f tiamat
  docker_stop_service mapmatching

  echo "Truncating eligible tables in jore4e2e, stopdb, and timetablesdb on $PGHOSTNAME:$PGPORT..."
  for DATABASE in jore4e2e stopdb timetablesdb; do
    PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$DATABASE" \
      -v ON_ERROR_STOP=1 -f "$CWD"/sql/truncate-tables.sql
  done

  echo "Restarting tiamat..."
  docker_start_service tiamat

  echo "Restarting mapmatching..."
  docker_start_service mapmatching
  while ! curl --fail http://localhost:3010/actuator/health --silent | grep --fixed-strings --quiet '{"status":"UP"}'
  do
    echo "waiting for tiamat db migrations to execute"
    sleep 2;
  done
  while ! curl --fail http://localhost:3005/actuator/health --silent | grep --fixed-strings --quiet '{"groups":["liveness","readiness"],"status":"UP"'
  do
    echo "waiting for mapmatching db migrations to execute"
    sleep 2;
  done

  echo "Restarting hasura..."
  docker_start_service hasura
  while ! curl --fail http://localhost:3201/healthz --output /dev/null --silent
  do
    echo "waiting for hasura db migrations to execute"
    sleep 2;
  done

  echo "Stopping services again to drive in infrastructure network"
  docker_stop_service hasura
  docker_stop_service tiamat
  docker_stop_service mapmatching

  echo "Importing infrastructure data from CSV file to jore4e2e on $PGHOSTNAME:$PGPORT..."
  # Import dump from csv file.
  INPUT_FILENAME="infra_network_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.csv"
  PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=1 -f "$CWD"/sql/import_infra_links_from_csv.sql -v csvfile="${WORK_DIR}/csv/${INPUT_FILENAME}"

  echo "Restarting tiamat..."
  docker_start_service tiamat
  while ! curl --fail http://localhost:3010/actuator/health --silent | grep --fixed-strings --quiet '{"status":"UP"}'
  do
    echo "waiting for tiamat db migrations to execute"
    sleep 2;
  done

  echo "Restarting mapmatching..."
  docker_start_service mapmatching
  while ! curl --fail http://localhost:3005/actuator/health --silent | grep --fixed-strings --quiet '{"groups":["liveness","readiness"],"status":"UP"'
  do
    echo "waiting for mapmatching db migrations to execute"
    sleep 2;
  done

  echo "Restarting hasura..."
  docker_start_service hasura
  while ! curl --fail http://localhost:3201/healthz --output /dev/null --silent
  do
    echo "waiting for hasura db migrations to execute"
    sleep 2;
  done

  echo "All done."
  exit 0
fi

ask TRUNCATE_EXISTING "Truncate existing infrastructure data before importing? [y/N]: " n y
if [[ "$TRUNCATE_EXISTING" =~ ^[Yy]$ ]]; then
  PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=1 -c "TRUNCATE TABLE infrastructure_network.vehicle_submode_on_infrastructure_link, infrastructure_network.infrastructure_link CASCADE;"
fi

# Import dump from csv file.
INPUT_FILENAME="infra_network_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.csv"
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
  -v ON_ERROR_STOP=1 -f "$CWD"/sql/import_infra_links_from_csv.sql -v csvfile="${WORK_DIR}/csv/${INPUT_FILENAME}"
