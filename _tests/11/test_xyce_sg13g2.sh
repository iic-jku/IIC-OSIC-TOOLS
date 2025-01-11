#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if Xyce simulations for SG13G2 PDK run (this also checks the PSP model).

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Switch to sg13g2 PDK
# shellcheck source=/dev/null
source iic-pdk-script.sh ihp-sg13g2 > /dev/null
# Run the simulations 
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_hbt_13g2.spice > /dev/null 2>&1 || ERROR=1
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_hv_nmos.spice > /dev/null 2>&1 || ERROR=1
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_hv_pmos.spice > /dev/null 2>&1 || ERROR=1
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_lv_nmos.spice > /dev/null 2>&1 || ERROR=1
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_lv_pmos.spice > /dev/null 2>&1 || ERROR=1
xyce -plugin $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_PSP103_VA.so $DIR/dc_res_temp.spice > /dev/null 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <xyce with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <xyce with ihp-sg13g2> passed."
    exit 0
fi
