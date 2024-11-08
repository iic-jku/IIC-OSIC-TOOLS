#!/bin/bash
# SPDX-FileCopyrightText: 2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if ngspice simulations for SG13G2 PDK run (this also checks the PSP OSDI model).

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Switch to sg13g2 PDK
# shellcheck source=/dev/null
source iic-pdk-script.sh sg13g2 > /dev/null
# Run the simulations
ngspice -b $DIR/dc_hbt_13g2.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/dc_hv_nmos.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/dc_hv_pmos.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/dc_lv_nmos.spice > /dev/null 2>&1 || ERROR=1
ngspice -b $DIR/dc_lv_pmos.spice > /dev/null 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <ngspice with sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <ngspice with sg13g2> passed."
    exit 0
fi
