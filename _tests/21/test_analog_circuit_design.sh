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

DEBUG=${DEBUG:-0}

TMP=/foss/designs/runs/${RAND}/21
LOG=$TMP/analog_circuit_design.log
REPO=analog-circuit-design

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the analog circuit design repository
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch) ..."
if ! git clone --branch main \
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

# Run the simulation testbenches. The repository's runner wraps the individual
# xschem/ngspice invocations in a throwaway virtual X server (xvfb-run) itself,
# so no plot windows pop up in headless mode.
[ "$DEBUG" = 1 ] && echo "[INFO] Running 'xschem/run_simulation_tests.sh' (output is logged to $LOG) ..."
if ./xschem/run_simulation_tests.sh >> "$LOG" 2>&1; then
    echo "[INFO] Test <analog-circuit-design with ihp-sg13g2> passed."
    exit 0
else
    echo "[ERROR] Test <analog-circuit-design with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    exit 1
fi
