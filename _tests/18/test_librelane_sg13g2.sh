#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test LibreLane for IHP-SG13G2

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

if command -v librelane >/dev/null 2>&1; then
    LOG=/foss/designs/runs/${RAND}/18/result_ll_sg13g2.log
    WORKDIR=/foss/designs/runs/${RAND}/18
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to ihp-sg13g2 PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh ihp-sg13g2 sg13g2_stdcell > /dev/null
    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    cp "$DIR"/* "$WORKDIR"
    librelane --manual-pdk "$WORKDIR/counter.json" > "$LOG"
    # Check if there is an error in the log
    if grep -q "ERROR" "$LOG"; then
        echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13g2> FAILED. Check the log <$LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with ihp-sg13g2> passed."
        exit 0
    fi
fi
