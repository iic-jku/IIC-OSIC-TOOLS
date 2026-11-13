#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test based on the course examples of
# <https://github.com/iic-jku/vlsi-design>.
#
# It clones the branch next_release of the repository, the next state of the
# course, and runs its `scripts/run_checks.sh` in regression mode: lint,
# simulation, synthesis, STA, ATPG, ngspice and LibreLane of every chapter
# with ihp-sg13cmos5l. It fails only on results that the exercises need.
# Values that the book quotes and a tool update changes are logged as drift.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

TMP=${RUNS_DIR}/${RAND}/49
LOG=$TMP/vlsi_design.log
REPO=vlsi-design

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the next_release branch of the VLSI design repository
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (next_release branch) ..."
if ! git clone --depth 1 --branch next_release \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <vlsi-design course examples with ihp-sg13cmos5l> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13cmos5l PDK (run_checks.sh also does it if needed)
[ "$DEBUG" = 1 ] && echo "[INFO] Switching to the ihp-sg13cmos5l PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l sg13cmos5l_stdcell > /dev/null

# Two chapters at a time: the LibreLane chapter runs two flows itself, and
# this test is one job of the parallel pool. VLSI_JOBS=<n> changes it by hand.
JOBS=${VLSI_JOBS:-2}
case $JOBS in '' | *[!0-9]* | 0) JOBS=2 ;; esac

[ "$DEBUG" = 1 ] && echo "[INFO] Running 'scripts/run_checks.sh' (JOBS=$JOBS, output is logged to $LOG) ..."
if CHECK_MODE=regression JOBS=$JOBS RUN_DIR=$TMP/checks \
        bash scripts/run_checks.sh >> "$LOG" 2>&1; then
    echo "[INFO] Test <vlsi-design course examples with ihp-sg13cmos5l> passed."
    exit 0
else
    echo "[ERROR] Test <vlsi-design course examples with ihp-sg13cmos5l> FAILED! Check the log file $LOG for details."
    exit 1
fi
