#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the smoke test of LibreLane runs successfully; if this works,
# many SW packages have to work properly, so this is a test with good
# coverage.
#
# We do this only for sky130A for now.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

if command -v librelane >/dev/null 2>&1; then
    LOG=/foss/designs/runs/${RAND}/01/result_ll_sky130a.log
    WORKDIR=/foss/designs/runs/${RAND}/01
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to sky130A PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh sky130A sky130_fd_sc_hd > /dev/null
    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    cp "$DIR"/* "$WORKDIR"
    librelane "$WORKDIR/counter.json" > "$LOG"
    # Check if there is an error in the log
    if grep -q "ERROR" "$LOG"; then
        echo "[ERROR] Test <LibreLane smoke-test with sky130A> FAILED. Check the log <$LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with sky130A> passed."
        exit 0
    fi
fi
