#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Set working directory into a variable.
CWD="$(dirname "$0")"

# Source common environment variables and functions.
source "$CWD"/set_env.sh

# Start Docker container.
#
# The container is expected to exist and contain Digiroad schema with data
# populated from shapefiles.
docker_start

# Generate HSL supplementary links and stop points.
docker_exec postgres "exec $PSQL -v ON_ERROR_STOP=1 -f /tmp/sql/add_hsl_fixup_data_for_dr_2025_01.sql -v schema=$DB_SCHEMA_NAME_DIGIROAD"

# Rewrite the GeoPackage file containing HSL's infrastructure network
# supplementing data.
"$CWD"/rewrite_fixup_geopkg.sh
