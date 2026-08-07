#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test based on the simulation testbenches of
# <https://github.com/iic-jku/analog-circuit-design>.
#
# It clones the repository and runs its `xschem/run_simulation_tests.sh`,
# which netlists every Xschem testbench with xschem (headless) and simulates
# it with ngspice in batch mode, scanning the logs for errors. This exercises
# the full analog simulation path (xschem -> ngspice + IHP SG13G2 PDK models).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

TMP=${RUNS_DIR}/${RAND}/21
LOG=$TMP/analog_circuit_design.log
REPO=analog-circuit-design

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the analog circuit design repository
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch) ..."
if ! git clone --depth 1 --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <analog-circuit-design with ihp-sg13g2> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13g2 PDK (sets PDK and PDK_ROOT, loads the OSDI models)
[ "$DEBUG" = 1 ] && echo "[INFO] Switching to the ihp-sg13g2 PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null

# Run the simulation testbenches. The runner takes care of the headless setup
# itself: it starts one shared Xvfb for the whole run and points every
# xschem/ngspice job at it (iic-jku/analog-circuit-design#78), so no plot
# windows pop up and nothing here has to provide a display. $DISPLAY is empty in
# the test container (see run_integration_tests.sh), which is what makes the runner
# set up its own server.
#
# JOBS: run a small pool of testbenches concurrently. This whole test is already
# one job of run_integration_tests.sh's GNU parallel pool (one job per core), so a
# per-core pool in here would oversubscribe the CPU by nproc^2; a pool of 4
# keeps the oversubscription bounded while dropping the wall clock from the sum
# of all testbench runtimes to roughly the longest one.
#
# SPICE_THREADS=1: ngspice threading does not pay off for these testbenches and
# badly hurts the two that dominate the runtime -- techsweep_sg13g2_lv_{n,p}mos
# sweep L x Vg x Vd x Vb and thus issue ~119k separate `run` commands on a
# single transistor each, where per-run OpenMP fork/join overhead is all that
# extra threads add (measured: 23 s with 1 thread vs 164 s with 9). Passed
# explicitly so the test does not depend on the age of the clone;
# iic-jku/analog-circuit-design#79 makes it the runner's default.
NPROC=$(nproc 2> /dev/null || echo 4)
JOBS=${ACD_JOBS:-4}
case $JOBS in '' | *[!0-9]* | 0) JOBS=4 ;; esac
[ "$JOBS" -gt "$NPROC" ] && JOBS=$NPROC

[ "$DEBUG" = 1 ] && echo "[INFO] Running 'xschem/run_simulation_tests.sh' (JOBS=$JOBS, output is logged to $LOG) ..."
if JOBS=$JOBS SPICE_THREADS=1 ./xschem/run_simulation_tests.sh >> "$LOG" 2>&1; then
    echo "[INFO] Test <analog-circuit-design with ihp-sg13g2> passed."
    exit 0
else
    echo "[ERROR] Test <analog-circuit-design with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    exit 1
fi
