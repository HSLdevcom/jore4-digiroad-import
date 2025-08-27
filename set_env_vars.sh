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

DB_HOST="localhost"
DB_PORT="5432"

# Commands to run inside Docker container.
export OGR2OGR_PG_REF="PG:\"host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USERNAME schemas=$DB_SCHEMA_NAME_DIGIROAD\""
export PGSQL2SHP="pgsql2shp -h $DB_HOST -p $DB_PORT -u $DB_USERNAME"
export PG_DUMP="pg_dump -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USERNAME --no-password"
export PG_WAIT="/wait-pg.sh $DB_NAME $DB_HOST $DB_PORT"
export PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME --no-password"

# In Linux, UID/GID mapping for `docker exec` fixes ownership/permission issues
# for files written inside Docker container in such a way that the Docker host
# user owns the files.
CURRUSER=$(id -u):$(id -g)
export CURRUSER

docker_start() {
  docker start "$DOCKER_CONTAINER_NAME"
}

docker_stop() {
  docker stop "$DOCKER_CONTAINER_NAME"
}

print_and_run_cmd() {
  echo "+ $*"
  "$@"
}

docker_exec() {
  local USER="$1"
  shift
  print_and_run_cmd docker exec -u "$USER" "$DOCKER_CONTAINER_NAME" sh -c "$@"
}
