#!/usr/bin/env bash

# Set correct working directory.
CWD="$(dirname "$0")"
export CWD
export WORK_DIR="${CWD}/workdir"

export DIGIROAD_IRROTUS_NRO=""
if [[ -f "$WORK_DIR/zip/digiroad_irrotus_nro.txt" ]]; then
  DIGIROAD_IRROTUS_NRO=$(cat "$WORK_DIR/zip/digiroad_irrotus_nro.txt")
fi

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

docker_kill() {
  # Remove possibly running/existing Docker container.
  docker kill "$DOCKER_CONTAINER_NAME" &> /dev/null || true
  docker rm -v "$DOCKER_CONTAINER_NAME" &> /dev/null || true
}

docker_pg_wait() {
  # Wait for PostgreSQL to be ready to accept connections.
  docker_exec postgres "exec $PG_WAIT"
}

docker_run() {
  local SHP_FILE_DIR="${1:-}"

  # If container already exists, just (re)start it.
  if docker container inspect "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1; then
    docker_start
    return 0
  fi

  if [[ -z "$SHP_FILE_DIR" ]]; then
    echo "Missing argument: SHP_FILE_DIR"
    echo "Usage: docker_run <path-to-shapefiles-dir>"
    return 1
  fi

  if [[ ! -d "$SHP_FILE_DIR" ]]; then
    echo "SHP_FILE_DIR does not exist or is not a directory: $SHP_FILE_DIR"
    return 1
  fi

  # Create directories that will be mounted to Docker container.
  mkdir -p "$WORK_DIR"/csv
  mkdir -p "$WORK_DIR"/mbtiles
  mkdir -p "$WORK_DIR"/pgdump

  # Create and start new Docker container. Mount all directories as volumes that
  # are needed by various processing scripts.
  docker run \
    --name "$DOCKER_CONTAINER_NAME" \
    -p 127.0.0.1:${DOCKER_CONTAINER_PORT}:5432 \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -v "$CWD"/fixup/digiroad:/tmp/gpkg \
    -v "$CWD"/sql:/tmp/sql \
    -v "$SHP_FILE_DIR":/tmp/shp \
    -v "$WORK_DIR"/csv:/tmp/csv \
    -v "$WORK_DIR"/mbtiles:/tmp/mbtiles \
    -v "$WORK_DIR"/pgdump:/tmp/pgdump \
    -d "$DOCKER_IMAGE"

  docker_pg_wait
}

docker_start() {
  if ! docker container inspect "$DOCKER_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Docker container $DOCKER_CONTAINER_NAME does not exist. Call docker_run first."
    return 1
  fi

  # Only start if not already running (safe to call repeatedly).
  if ! docker container inspect -f '{{.State.Running}}' "$DOCKER_CONTAINER_NAME" 2>/dev/null | grep -q '^true$'; then
    docker start "$DOCKER_CONTAINER_NAME"
  fi

  docker_pg_wait
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
