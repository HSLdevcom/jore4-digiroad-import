#!/usr/bin/env bash

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

# Create a zip archive containing HSL QGIS fixup project.
mkdir -p "$WORK_DIR"/zip

zip -r "${WORK_DIR}/zip/${DIGIROAD_IRROTUS_NRO}_$(date "+%Y-%m-%d")_hsl_qgis_fixup_project.zip" \
  fixup/jore4-digiroad-fix-project.qgz \
  fixup/digiroad workdir/shp/UUSIMAA/
