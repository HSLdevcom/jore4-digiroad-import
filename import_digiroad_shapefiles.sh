#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

# Source common environment variables and functions.
source "$(dirname "$0")/set_env.sh"

AREA="UUSIMAA"

SHP_URL="https://aineistot.vayla.fi/?path=ava/Tie/Digiroad/Aineistojulkaisut/latest/Maakuntajako_digiroad_R/${AREA}.zip"
IRROTUS_NRO_URL="https://aineistot.vayla.fi/?path=ava/Tie/Digiroad/Aineistojulkaisut/latest/irrotus_nro.txt"

DOWNLOAD_TARGET_DIR="${WORK_DIR}/zip"
DOWNLOAD_TARGET_FILE="${DOWNLOAD_TARGET_DIR}/${AREA}_R.zip"

# Load zip file containing Digiroad shapefiles if it does not exist.
if [[ ! -f "$DOWNLOAD_TARGET_FILE" ]]; then
  mkdir -p "$DOWNLOAD_TARGET_DIR"
  COOKIE_JAR="${DOWNLOAD_TARGET_DIR}/curl.cookies"
  set +e
  output=$(curl -L -c "$COOKIE_JAR" -b "$COOKIE_JAR" -o "$DOWNLOAD_TARGET_FILE" "$SHP_URL" 2>&1)
  exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    rm $COOKIE_JAR
    echo "Error downloading shapefile zip file from $SHP_URL. Curl exit code: $exit_code"
    exit $exit_code
  fi


  DIGIROAD_IRROTUS_NRO=$(curl -sL -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$IRROTUS_NRO_URL" 2>&1 | tr '_' '-')

  exit_code=$?
  rm $COOKIE_JAR
  set -e
  if [[ $exit_code -ne 0 ]]; then
    echo "Error downloading irrotus_nro file from $IRROTUS_NRO_URL. Curl exit code: $exit_code"
    exit $exit_code
  fi

  if [[ ! -f "${DOWNLOAD_TARGET_DIR}/digiroad_${DIGIROAD_IRROTUS_NRO}.txt" ]]; then
    echo $DIGIROAD_IRROTUS_NRO > "${DOWNLOAD_TARGET_DIR}/digiroad_${DIGIROAD_IRROTUS_NRO}.txt"
  fi
  echo $DIGIROAD_IRROTUS_NRO >| "${DOWNLOAD_TARGET_DIR}/digiroad_irrotus_nro.txt"
fi

SUB_AREAS="ITA-UUSIMAA UUSIMAA_1 UUSIMAA_2"
SHP_FILE_DIR="${WORK_DIR}/shp/${AREA}"

for SUB_AREA in $SUB_AREAS; do
  mkdir -p "${SHP_FILE_DIR}/${SUB_AREA}"
  # Extract all shapefiles within sub-area.
  unzip -u "$DOWNLOAD_TARGET_FILE" "$SUB_AREA"/* -d "$SHP_FILE_DIR"
done

# Extract shapefile for public transport stops (common to all sub-areas of Uusimaa).
unzip -u "$DOWNLOAD_TARGET_FILE" PYSAKIT/PYSAKIT.zip -d "${DOWNLOAD_TARGET_DIR}/${AREA}"
unzip -u "${DOWNLOAD_TARGET_DIR}/${AREA}/PYSAKIT/PYSAKIT.zip" -d "$SHP_FILE_DIR"
rm -fr "${DOWNLOAD_TARGET_DIR:?}/${AREA}"

# Extract general Digiroad documents.
unzip -u "$DOWNLOAD_TARGET_FILE" Dokumentit/* -d "$DOWNLOAD_TARGET_DIR"

# Remove possibly running/existing Docker container.
docker_kill

# Create and start new Docker container.
docker_run "$SHP_FILE_DIR"

# Create digiroad import schema into database.
docker_exec postgres "exec $PSQL -nt -c \"CREATE SCHEMA ${DB_SCHEMA_NAME_DIGIROAD};\""

SHP2PGSQL="shp2pgsql -D -i -s 3067 -S -N abort -W $SHP_ENCODING"

# Load only selected shapefiles into database.
SUB_AREA_SHP_TYPES="DR_LINKKI DR_KAANTYMISRAJOITUS"

for SUB_AREA_SHP_TYPE in $SUB_AREA_SHP_TYPES; do
  # Derive lowercase table name for shape type.
  TABLE_NAME="${DB_SCHEMA_NAME_DIGIROAD}.$(echo "$SUB_AREA_SHP_TYPE" | awk '{print tolower($0)}')"

  # Create database table for each shape type.
  docker_exec postgres "$SHP2PGSQL -p /tmp/shp/${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | exec $PSQL -v ON_ERROR_STOP=1 -q"

  # Populate database table from multiple shapefiles from sub areas.
  docker_exec postgres "for SUB_AREA in ${SUB_AREAS}; do $SHP2PGSQL -a /tmp/shp/\${SUB_AREA}/${SUB_AREA_SHP_TYPE}.shp $TABLE_NAME | exec $PSQL -v ON_ERROR_STOP=1; done"
done

# Stop Docker container.
docker_stop
