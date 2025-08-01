#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if DRC and LVS are OK on a simple inverter in sky130A.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT=/foss/designs/runs/${RAND}/02/result_layver_sky130a.log
WORKDIR=/foss/designs/runs/${RAND}/02

mkdir -p "$WORKDIR"

# Switch to sky130A PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > "$RESULT" 2>&1
# Run the DRC
sak-drc.sh -w "$WORKDIR" -b "$DIR/inv.mag"  > "$RESULT" 2>&1 || ERROR=1
# Run the LVS
echo sak-lvs.sh -w "$WORKDIR" -s "$DIR/inv.sch" -l "$DIR/inv.mag" -c inv  > "$RESULT" 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <LayVer of sky130 inv> FAILED."
    exit 1
else
    echo "[INFO] Test <LayVer of sky130 inv> passed."
    exit 0
fi
