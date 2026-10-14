#!/bin/bash
# SPDX-FileCopyrightText: 2026 Julian Schwarz
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test for the open-pdks regression-test suite with ihp-sg13cmos5l
# (https://github.com/iic-jku/open-pdks-regression-tests)

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

TMP=${RUNS_DIR}/${RAND}/31
LOG=$TMP/drc_lvs_pex_sg13cmos5l.log
REPO=open-pdks-regression-tests

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the open-pdks regression tests (incl. submodules)
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch, incl. submodules) ..."
if ! git clone --depth 1 --recursive --shallow-submodules --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <open-pdks regression tests with ihp-sg13cmos5l> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO/ihp-sg13cmos5l" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13cmos5l PDK
[ "$DEBUG" = 1 ] && echo "[INFO] Switching to the ihp-sg13cmos5l PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l sg13cmos5l_stdcell > /dev/null

# Run the regression target and check the result
[ "$DEBUG" = 1 ] && echo "[INFO] Running 'make regression' (output is logged to $LOG) ..."
if make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <open-pdks regression tests with ihp-sg13cmos5l> passed."
    exit 0
else
    echo "[ERROR] Test <open-pdks regression tests with ihp-sg13cmos5l> FAILED! Check the log file $LOG for details."
    exit 1
fi
