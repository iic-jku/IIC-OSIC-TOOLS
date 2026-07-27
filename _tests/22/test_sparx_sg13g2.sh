#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test based on the SPARX six-port receiver of
# <https://github.com/iic-jku/SG13CMOS_SPARX>.
#
# It clones the repository and runs its `make regression` target, which builds
# the layout (gdsfactory), verifies it (magic), runs an EM simulation (palace),
# converts the S-parameters to a lumped-element model (snp2le) and simulates
# the result with ngspice and VACASK (xschem).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_docker_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

TMP=${RUNS_DIR}/${RAND}/22
LOG=$TMP/sparx_sg13g2.log
REPO=SG13CMOS_SPARX

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the SPARX repository
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch) ..."
if ! git clone --depth 1 --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <SPARX with ihp-sg13g2> FAILED! Could not clone the repository. Check the log file $LOG for details."
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

# Run the regression target and check the result.
# With DEBUG=1, run interactively so the ngspice/xschem plots are shown. 
# Otherwise, run headless under a throwaway virtual X server (xvfb-run) so no plot windows pop up.
SIM_WRAP="xvfb-run -a"
[ "$DEBUG" = 1 ] && SIM_WRAP=""
[ "$DEBUG" = 1 ] && echo "[INFO] Running 'make regression' (output is logged to $LOG) ..."
# shellcheck disable=SC2086
if $SIM_WRAP make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <SPARX with ihp-sg13g2> passed."
    exit 0
else
    echo "[ERROR] Test <SPARX with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    exit 1
fi
