#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test LibreLane for IHP-SG13CMOS5L

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

if command -v librelane >/dev/null 2>&1; then
    LOG=/foss/designs/runs/${RAND}/19/result_ll_sg13cmos5l.log
    WORKDIR=/foss/designs/runs/${RAND}/19
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to ihp-sg13cmos5l PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh ihp-sg13cmos5l sg13cmos5l_stdcell > /dev/null
    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    find "$DIR" -maxdepth 1 -type f -exec cp {} "$WORKDIR" \;
    librelane --manual-pdk "$WORKDIR/counter.json" > "$LOG"
    # Check if there is an error in the log
    if grep -q "ERROR" "$LOG"; then
        echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13cmos5l> FAILED. Check the log <$LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with ihp-sg13cmos5l> passed."
        exit 0
    fi
else
    echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13cmos5l> FAILED. LibreLane is not installed!"
    exit 1
fi
