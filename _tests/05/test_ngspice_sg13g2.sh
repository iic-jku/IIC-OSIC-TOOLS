#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if ngspice simulations for SG13G2 PDK run (this also checks the PSP OSDI model).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=/foss/designs/runs/${RAND}/05

mkdir -p "$WORKDIR"

# Switch to sg13g2 PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null
# Run the simulations
ngspice --rawfile="$WORKDIR"/run1.raw --output="$WORKDIR"/run1.log -b "$DIR"/dc_hbt_13g2.spice > /dev/null 2>&1 || ERROR=1
ngspice --rawfile="$WORKDIR"/run2.raw --output="$WORKDIR"/run2.log -b "$DIR"/dc_hv_nmos.spice  > /dev/null 2>&1 || ERROR=1
ngspice --rawfile="$WORKDIR"/run3.raw --output="$WORKDIR"/run3.log -b "$DIR"/dc_hv_pmos.spice  > /dev/null 2>&1 || ERROR=1
ngspice --rawfile="$WORKDIR"/run4.raw --output="$WORKDIR"/run4.log -b "$DIR"/dc_lv_nmos.spice  > /dev/null 2>&1 || ERROR=1
ngspice --rawfile="$WORKDIR"/run5.raw --output="$WORKDIR"/run5.log -b "$DIR"/dc_lv_pmos.spice  > /dev/null 2>&1 || ERROR=1
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <ngspice with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <ngspice with ihp-sg13g2> passed."
    exit 0
fi
