#!/bin/bash
# SPDX-FileCopyrightText: 2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the <https://www.zerotoasiccourse.com> examples of Matt Venn

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

set -euo pipefail

TMP=/foss/designs/runs/${RAND}/13
LOG=/foss/designs/runs/${RAND}/13/z2a.log
mkdir -p "$TMP"
cd "$TMP" || exit 1

git clone --recursive https://github.com/mattvenn/z2a-course-regressions.git > "$LOG" 2>&1
cd z2a-course-regressions || exit 1

# unset DISPLAY otherwise ngspice will fail with an error
unset DISPLAY

if make > "$LOG" 2>&1; then
    echo "[INFO] Test <Zero2ASIC> passed."
    exit 0
else
    echo "[ERROR] Test <Zero2ASIC> FAILED! Check the log file $LOG for details."
    exit 1
fi
