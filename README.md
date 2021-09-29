# jore4-digiroad-import-experiment

## Overview

This repository provides scripts to download Digiroad shapefiles for road and stop geometries and make transformations required by JORE4 components/services.

Firstly, Digiroad links and other related information is downloaded and imported from shapefiles into a PostGIS database (contained in a Docker container) by executing `import_digiroad_shapefiles.sh` script. Within script execution the data is further processed in the database after which the data can be exported in a couple of formats relevant to JORE4 services.

The database is used only locally for processing data. Each invocation of main import script will recreate the Docker container and reset the state of database.

## Usage

Initially, you need to build the Docker image containing PostGIS database with:

```
./build_docker_image.sh
```

Secondly, Digiroad shapefiles are downloaded and imported into PostGIS database inside a Docker container with further processing done by executing:

```
./import_digiroad_shapefiles.sh
```

A pg_dump file containing imported (and processed) Digiroad tables can be exported with (given that Digiroad material has already been imported):

```
./export_pgdump_digiroad.sh
```

At the moment, there is no specific use case for the dump generated with the above command. However, it is planned that a separate schema will be generated later that will contain the infrastructure tables and columns used in JORE4 database.

A pg_dump file containing links, stops and routing topology can be exported with (given that Digiroad material has already been imported):

```
./export_pgdump_routing.sh
```

A sql file containing links, stops and routing topology can be exported with
(given that Digiroad material has already been imported):

```
./export_sql_routing.sh
```

Upload sql dumps to Azure blob storage:

```
./upload_to_azure.sh
```

An MBTiles files containing road links can be exported with (given that Digiroad
material has already been imported):

```
./export_mbtiles_dr_linkki.sh
```

An MBTiles files containing stops can be exported with (given that Digiroad material has already been imported):

```
./export_mbtiles_dr_pysakki.sh
```

## Target database initialisation

Before importing pg_dump file into target database the database must be added postgis extension. E.g. the following commands create database and user named "digiroad" and add postgis extension to the newly-created database. Remember to set up passwords as you wish.

```
CREATE DATABASE digiroad;
CREATE USER digiroad;
GRANT ALL PRIVILEGES ON DATABASE digiroad TO digiroad;
\c digiroad
CREATE EXTENSION postgis;
CREATE EXTENSION pgrouting;
```
