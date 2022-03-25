#!/usr/bin/env bash

# Source common environment variables.
source "$(cd "$(dirname "$0")"; pwd -P)/set_env_vars.sh"

# Create a zip archive containing failing stop-to-stop segments.
mkdir -p $WORK_DIR/zip  
zip -r $WORK_DIR/zip/failing_stop2stop_segments.zip fixup/jore4-digiroad-fix-project.qgs fixup/digiroad workdir/shp/UUSIMAA/
