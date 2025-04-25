#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the smoke test of OpenLane2 runs successfully; if this works,
# many SW packages have to work properly, so this is a test with good
# coverage.
#
# We do this only for gf180mcuD for now.

if command -v openlane >/dev/null 2>&1; then
    RESULT=/tmp/result_ol_gf180mcud.log
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to gf180mcuD PDK
    # shellcheck source=/dev/null
    source iic-pdk-script.sh gf180mcuD gf180mcu_fd_sc_mcu7t5v0 > /dev/null
    # Run the OpenLane2 smoke test
    mkdir -p /tmp/ol2_gf180mcu
    cp "$DIR"/counter.* /tmp/ol2_gf180mcu
    openlane --manual-pdk /tmp/ol2_gf180mcu/counter.json > $RESULT
    # Check if there is an error in the log
    if grep -q "ERROR" "$RESULT"; then
        echo "[ERROR] Test <OpenLane smoke-test with gf180mcuD> FAILED."
        exit 1
    else
        echo "[INFO] Test <OpenLane smoke-test with gf180mcuD> passed."
        exit 0
    fi
fi
