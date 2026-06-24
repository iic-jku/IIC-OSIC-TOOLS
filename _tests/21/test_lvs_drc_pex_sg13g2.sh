#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test for the open-pdks regression-test suite with ihp-sg13g2
# (https://github.com/iic-jku/open-pdks-regression-tests)

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

TMP=/foss/designs/runs/${RAND}/21
LOG=$TMP/lvs_drc_pex_sg13g2.log
REPO=open-pdks-regression-tests

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the open-pdks regression tests (incl. submodules)
echo "[INFO] Cloning $REPO (main branch, incl. submodules) ..."
if ! git clone --recursive --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1; then
    echo "[ERROR] Test <open-pdks regression tests with ihp-sg13g2> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi
cd "$REPO/ihp-sg13g2" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13g2 PDK
echo "[INFO] Switching to the ihp-sg13g2 PDK ..."
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 sg13g2_stdcell > /dev/null

# Run the regression target and check the result
echo "[INFO] Running 'make regression' (output is logged to $LOG) ..."
if make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <open-pdks regression tests with ihp-sg13g2> passed."
    exit 0
else
    echo "[ERROR] Test <open-pdks regression tests with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    exit 1
fi
