#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the IHP-SG13G2 AMS chip template
# (https://github.com/iic-jku/ihp-sg13g2-ams-chip-template)

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

TMP=/foss/designs/runs/${RAND}/20
LOG=$TMP/ams_chip_sg13g2.log
REPO=ihp-sg13g2-ams-chip-template

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the AMS chip template (incl. submodules)
[ "$DEBUG" = 1 ] && echo "[INFO] Cloning $REPO (main branch, incl. submodules) ..."
if ! git clone --recursive --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <AMS chip template with ihp-sg13g2> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13g2 PDK
[ "$DEBUG" = 1 ] && echo "[INFO] Switching to the ihp-sg13g2 PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 sg13g2_stdcell > /dev/null

# Run the regression target and check the result.
# With DEBUG=1, run interactively so the ngspice/xschem plots are shown. 
# Otherwise, run headless under a throwaway virtual X server (xvfb-run) so no plot windows pop up.
SIM_WRAP="xvfb-run -a"
[ "$DEBUG" = 1 ] && SIM_WRAP=""
[ "$DEBUG" = 1 ] && echo "[INFO] Running 'make regression' (output is logged to $LOG) ..."
# shellcheck disable=SC2086
if $SIM_WRAP make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <AMS chip template with ihp-sg13g2> passed."
    exit 0
else
    echo "[ERROR] Test <AMS chip template with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    exit 1
fi
