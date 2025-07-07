#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if ngspice simulations for gf180mcuD PDK run.

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Switch to gf180mcuD PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD > /dev/null
# Run the simulations
ngspice -b $DIR/inv_tb.spice > /dev/null 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <ngspice with gf180mcuD> FAILED."
    exit 1
else
    echo "[INFO] Test <ngspice with gf180mcuD> passed."
    exit 0
fi
