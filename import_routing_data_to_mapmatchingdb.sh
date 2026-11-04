#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

usage() {
  echo "Usage: $(basename "$0") [--with-defaults] <ROUTING_SCHEMA_CREATION_DATE> <MML_TRAM_IMPORT_DATE>"
  echo "  ROUTING_SCHEMA_CREATION_DATE must be in format YYYY-MM-DD"
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

ROUTING_SCHEMA_CREATION_DATE="$1"
if [[ ! "$ROUTING_SCHEMA_CREATION_DATE" =~ ^20[2-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "Invalid date: $ROUTING_SCHEMA_CREATION_DATE"
  usage
  exit 1
fi

MML_TRAM_IMPORT_DATE="$2"
if [[ ! "$MML_TRAM_IMPORT_DATE" =~ ^20[2-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "Invalid date: $MML_TRAM_IMPORT_DATE"
  usage
  exit 1
fi

ROUTING_DUMP_FILE="workdir/pgdump/${ROUTING_SCHEMA_CREATION_DATE}_create_routing_schema_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.pgdump"

# Reading connection parameters
echo "Please fill in the connection parameters for the mapmatching database to import the data to:"
ask PGHOSTNAME "Hostname (default: localhost): " localhost
ask PGDATABASE "Database name (default: jore4mapmatching): " jore4mapmatching
ask PGPORT "Port (default: 6433): " 6433
ask PGUSERNAME "Username (default: mapmatching): " mapmatching
ask PGPASSWORD "Password (default: password): " password

ask TRUNCATE_ALL_DATABASES "Truncate data in eligible tables in jore4mapmatching on $PGHOSTNAME:$PGPORT? [y/N]: " n y
if [[ ! "$TRUNCATE_ALL_DATABASES" =~ ^[Yy]$ ]]; then
    echo Aborting.
    exit 1
fi

echo "Truncating eligible tables in jore4mapmatching on $PGHOSTNAME:$PGPORT..."
PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
    -v ON_ERROR_STOP=1 \
    -c "TRUNCATE TABLE routing.infrastructure_source CASCADE; TRUNCATE TABLE routing.infrastructure_link_vertices_pgr CASCADE; TRUNCATE TABLE routing.public_transport_stop CASCADE;"

echo "Importing routing data from $ROUTING_DUMP_FILE into jore4mapmatching on $PGHOSTNAME:$PGPORT..."
PGPASSWORD="$PGPASSWORD" pg_restore -1 -a --use-list="${ROUTING_DUMP_FILE}.no-enums.links-and-stops.list" \
    -h "$PGHOSTNAME" -p "$PGPORT" -d "$PGDATABASE" -U "$PGUSERNAME" "$ROUTING_DUMP_FILE"
