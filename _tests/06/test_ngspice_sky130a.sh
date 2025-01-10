#!/bin/bash
# SPDX-FileCopyrightText: 2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if ngspice simulations for sky130A PDK run.

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Switch to sky130A PDK
# shellcheck source=/dev/null
source iic-pdk-script.sh sky130A > /dev/null
# Run the simulations
ngspice -b $DIR/test_nmos.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/test_pmos.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/test_analog.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/test_boris.spice > /dev/null 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <ngspice with sky130a> FAILED."
    exit 1
else
    echo "[INFO] Test <ngspice with sky130a> passed."
    exit 0
fi
