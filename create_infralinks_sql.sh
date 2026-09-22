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

ask CONFIRM_IMPORT "Have you ran import_infra_network_csv.sh? (y/N): " n y
if [[ "$CONFIRM_IMPORT" != "y" && "$CONFIRM_IMPORT" != "Y" ]]; then
  echo "Please run import_infra_network_csv.sh before running this script."
  exit 1
fi

OUTPUT_FILENAME="infraLinks_digiroad_r_${DIGIROAD_IRROTUS_NRO}_mml_${MML_TRAM_IMPORT_DATE}.sql"

# Reading connection parameters
echo "Please fill in the connection parameters for the database to import the data to:"
ask PGHOSTNAME "Hostname (default: localhost): " localhost
ask PGDATABASE "Database name (default: jore4e2e): " jore4e2e
ask PGPORT "Port (default: 6432): " 6432
ask PGUSERNAME "Username (default: dbadmin): " dbadmin
ask PGPASSWORD "Password (default: adminpassword): " adminpassword

cat <<EOF > "$OUTPUT_FILENAME"
-- Digiroad infrastructure data licensed with Creative Commons BY 4.0 license by the Finnish Transport Infrastructure
-- Agency https://vayla.fi/en/transport-network/data/digiroad/data
--
-- Tram infrastructure data from National Land Survey of Finland Topographic Database (Maanmittauslaitos) $MML_TRAM_IMPORT_DATE

--
-- Data for Name: infrastructure_link; Type: TABLE DATA; Schema: infrastructure_network; Owner: -
--

COPY infrastructure_network.infrastructure_link (infrastructure_link_id, direction, shape, estimated_length_in_metres, external_link_id, external_link_source) FROM stdin;
EOF

PGPASSWORD="$PGPASSWORD" psql -h "$PGHOSTNAME" -p "$PGPORT" -U "$PGUSERNAME" -d "$PGDATABASE" \
  -v ON_ERROR_STOP=1 \
  -c "COPY (
    SELECT
      infrastructure_link_id,
      direction,
      shape,
      estimated_length_in_metres,
      external_link_id,
      external_link_source
    FROM infrastructure_network.infrastructure_link
  ) TO STDOUT" >> "$OUTPUT_FILENAME"

cat <<EOF >> "$OUTPUT_FILENAME"
\.


-- Insert vehicle submode information for infrastructure links

INSERT INTO infrastructure_network.vehicle_submode_on_infrastructure_link
    (infrastructure_link_id, vehicle_submode)
    SELECT
        il.infrastructure_link_id,
        CASE il.external_link_source
            WHEN 'digiroad_r_mml' THEN 'generic_bus'
            WHEN 'digiroad_r_supplementary' THEN 'generic_bus'
            WHEN 'hsl_fixup' THEN 'generic_bus'
            WHEN 'hsl_tram' THEN 'generic_tram'
            WHEN 'temp_hsl_tram' THEN 'generic_tram'
        END
    FROM infrastructure_network.infrastructure_link il
    ON CONFLICT (infrastructure_link_id, vehicle_submode) DO NOTHING;
EOF
