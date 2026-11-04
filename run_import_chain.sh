#!/usr/bin/env bash

# Stop on first error. Have meaningful error messages.
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <MML_DATE>"
  echo "  MML_DATE must be in format YYYY-MM-DD"
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

MML_DATE="$1"
if [[ ! "$MML_DATE" =~ ^20[2-9][0-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "Invalid date: $MML_DATE"
  usage
  exit 1
fi

echo "Running import chain for MML_DATE=$MML_DATE"
echo
echo Expects the docker containers have bees set up by the jore3-importer project:
echo "~/src/hsl/jore4-jore3-importer % ./development.sh start:deps --volumes --flyway-baseline --delete-volumes"

echo
echo
echo "**************************************************************"
echo
echo "              import_digiroad_shapefiles.sh"
echo
echo "**************************************************************"
./import_digiroad_shapefiles.sh

echo
echo
echo "**************************************************************"
echo
echo "              import_tram_links.sh"
echo
echo "**************************************************************"
./import_tram_links.sh "$MML_DATE"

echo
echo
echo "**************************************************************"
echo
echo "              apply_fixup_layer_and_process_links.sh"
echo
echo "**************************************************************"
./apply_fixup_layer_and_process_links.sh

echo
echo
echo "**************************************************************"
echo
echo "              export_routing_schema.sh"
echo
echo "**************************************************************"
./export_routing_schema.sh "$MML_DATE"

echo
echo
echo "**************************************************************"
echo
echo "              import_routing_data_to_mapmatchingdb.sh"
echo
echo "**************************************************************"
./import_routing_data_to_mapmatchingdb.sh `date "+%Y-%m-%d"` "$MML_DATE" --with-defaults

echo
echo
echo "**************************************************************"
echo
echo "              export_infra_network_csv.sh"
echo
echo "**************************************************************"
./export_infra_network_csv.sh "$MML_DATE"

echo
echo
echo "**************************************************************"
echo
echo "              import_infra_network_csv.sh"
echo
echo "**************************************************************"
./import_infra_network_csv.sh --with-defaults "$MML_DATE"

echo
echo
echo "**************************************************************"
echo
echo "              create_infralinks_sql.sh"
echo
echo "**************************************************************"
./create_infralinks_sql.sh --with-defaults "$MML_DATE"

echo
echo
echo "**************************************************************"
echo
echo "              export_stops_csv.sh"
echo
echo "**************************************************************"
./export_stops_csv.sh

echo
echo
echo "Not exporting mbtiles. Exiting."
echo
exit

echo
echo
echo "**************************************************************"
echo
echo "              export_mbtiles_dr_linkki.sh"
echo
echo "**************************************************************"
./export_mbtiles_dr_linkki.sh

echo
echo
echo "**************************************************************"
echo
echo "              export_mbtiles_dr_pysakki.sh"
echo
echo "**************************************************************"
./export_mbtiles_dr_pysakki.sh

echo
echo
echo "**************************************************************"
echo
echo "              export_mbtiles_tram_links.sh"
echo
echo "**************************************************************"
./export_mbtiles_tram_links.sh "$MML_DATE"
