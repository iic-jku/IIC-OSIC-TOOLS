#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if DRC and LVS are OK on a simple inverter in sky130A.

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Switch to sky130A PDK
# shellcheck source=/dev/null
source iic-pdk-script.sh sky130A > /dev/null
# Run the DRC
iic-drc.sh -w /tmp -b "$DIR/inv.mag" > /dev/null || ERROR=1
# Run the LVS
iic-lvs.sh -w /tmp -s "$DIR/inv.sch" -l "$DIR/inv.mag" -c inv > /dev/null || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <LayVer of sky130 inv> FAILED."
    exit 1
else
    echo "[INFO] Test <LayVer of sky130 inv> passed."
    exit 0
fi
