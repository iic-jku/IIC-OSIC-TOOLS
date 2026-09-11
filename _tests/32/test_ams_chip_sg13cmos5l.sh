#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the IHP-SG13CMOS5L AMS chip template
# (https://github.com/iic-jku/ihp-sg13cmos5l-ams-chip-template)

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

TMP=${RUNS_DIR}/${RAND}/32
LOG=$TMP/ams_chip_sg13cmos5l.log
REPO=ihp-sg13cmos5l-ams-chip-template

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the AMS chip template (incl. submodules)
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch, incl. submodules) ..."
if ! git clone --depth 1 --recursive --shallow-submodules --branch next_release \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <AMS chip template with ihp-sg13cmos5l> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13cmos5l PDK
[ "$DEBUG" = 1 ] && echo "[INFO] Switching to the ihp-sg13cmos5l PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l sg13cmos5l_stdcell > /dev/null

# Run the regression target and check the result.
# With DEBUG=1, run interactively so the ngspice/xschem plots are shown.
# Otherwise, run headless under a throwaway virtual X server (xvfb-run) so no plot windows pop up.
SIM_WRAP="xvfb-run -a"
[ "$DEBUG" = 1 ] && SIM_WRAP=""
[ "$DEBUG" = 1 ] && echo "[INFO] Running 'make regression' (output is logged to $LOG) ..."
# shellcheck disable=SC2086
if $SIM_WRAP make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <AMS chip template with ihp-sg13cmos5l> passed."
    exit 0
else
    echo "[ERROR] Test <AMS chip template with ihp-sg13cmos5l> FAILED! Check the log file $LOG for details."
    exit 1
fi
