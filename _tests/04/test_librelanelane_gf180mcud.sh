#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the smoke test of LibreLane runs successfully; if this works,
# many SW packages have to work properly, so this is a test with good
# coverage.
#
# We do this only for gf180mcuD for now.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

if command -v librelane >/dev/null 2>&1; then
    LOG=/foss/designs/runs/${RAND}/04/result_ll_sky130a.log
    WORKDIR=/foss/designs/runs/${RAND}/04
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to gf180mcuD PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh gf180mcuD gf180mcu_fd_sc_mcu7t5v0 > /dev/null

    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    cp "$DIR"/* "$WORKDIR"
    librelane "$WORKDIR"/counter.json > "$LOG"
    # Check if there is an error in the log
    if grep -q "ERROR" "$LOG"; then
        echo "[ERROR] Test <LibreLane smoke-test with gf180mcuD> FAILED. Check the log <$LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with gf180mcuD> passed."
        exit 0
    fi
fi
