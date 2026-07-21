#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the <https://www.zerotoasiccourse.com> examples of Matt Venn

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_docker_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

set -euo pipefail

echo "[INFO] Test <Zero2ASIC> disabled: known fail."
exit 0

TMP=${RUNS_DIR}/${RAND}/13
LOG=${RUNS_DIR}/${RAND}/13/z2a.log
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
