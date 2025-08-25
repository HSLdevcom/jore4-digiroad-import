#!/usr/bin/env bash

# Set correct working directory.
CWD="$(cd "$(dirname "$0")" || exit; pwd -P)"
export CWD
export WORK_DIR="${CWD}/workdir"

# shapefile encoding
export SHP_ENCODING="UTF-8"

export DOCKER_IMAGE="jore4/postgis-digiroad"
export DOCKER_CONTAINER_NAME="jore4-postgis-digiroad"
export DOCKER_CONTAINER_PORT="21000"

# Database details
LOCAL_DB_NAME="digiroad"
export DB_NAME="$LOCAL_DB_NAME"
export DB_USERNAME="digiroad"
export DB_SCHEMA_NAME_DIGIROAD="digiroad"
export DB_SCHEMA_NAME_MBTILES="mbtiles"
export DB_SCHEMA_NAME_ROUTING="routing"

DB_HOST="\$POSTGRES_PORT_5432_TCP_ADDR"
DB_PORT="\$POSTGRES_PORT_5432_TCP_PORT"

# Commands to run inside Docker container.
export OGR2OGR_PG_REF="PG:\"host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USERNAME schemas=$DB_SCHEMA_NAME_DIGIROAD\""
export PGSQL2SHP="pgsql2shp -h \"$DB_HOST\" -p \"$DB_PORT\" -u $DB_USERNAME"
export PG_DUMP="exec pg_dump -h \"$DB_HOST\" -p \"$DB_PORT\" -d $DB_NAME -U $DB_USERNAME --no-password"
export PG_WAIT="exec /wait-pg.sh $DB_NAME \"$DB_HOST\" \"$DB_PORT\""
export PG_WAIT_LOCAL="exec /wait-pg.sh $LOCAL_DB_NAME localhost 5432"
export PSQL="exec psql -h \"$DB_HOST\" -p \"$DB_PORT\" -U $DB_USERNAME -d $DB_NAME --no-password"
