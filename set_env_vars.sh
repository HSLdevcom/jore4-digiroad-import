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
export DB_NAME="digiroad"
export DB_SCHEMA_NAME_DIGIROAD="digiroad"
export DB_SCHEMA_NAME_MBTILES="mbtiles"
export DB_SCHEMA_NAME_ROUTING="routing"

# Commands to run inside Docker container.
export PSQL="exec psql -h \"\$POSTGRES_PORT_5432_TCP_ADDR\" -p \"\$POSTGRES_PORT_5432_TCP_PORT\" -U digiroad -d $DB_NAME --no-password"
export PG_WAIT="exec /wait-pg.sh $DB_NAME \"\$POSTGRES_PORT_5432_TCP_ADDR\" \"\$POSTGRES_PORT_5432_TCP_PORT\""
export PG_WAIT_LOCAL="exec /wait-pg.sh $DB_NAME localhost \"\$POSTGRES_PORT_5432_TCP_PORT\""
export PG_DUMP="exec pg_dump -h \"\$POSTGRES_PORT_5432_TCP_ADDR\" -p \"\$POSTGRES_PORT_5432_TCP_PORT\" -d $DB_NAME -U digiroad --no-password"
