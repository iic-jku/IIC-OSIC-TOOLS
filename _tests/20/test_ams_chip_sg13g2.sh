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

set -euo pipefail

TMP=/foss/designs/runs/${RAND}/20
LOG=/foss/designs/runs/${RAND}/20/ams_chip_sg13g2.log
REPO=ihp-sg13g2-ams-chip-template

mkdir -p "$TMP"
cd "$TMP" || exit 1

# Clone the main branch of the AMS chip template (incl. submodules)
git clone --recursive --branch main \
    https://github.com/iic-jku/"$REPO".git "$REPO" > "$LOG" 2>&1
cd "$REPO" || exit 1

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$TMP/$REPO"

# Switch to the ihp-sg13g2 PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 sg13g2_stdcell > /dev/null

# Run the regression target and check the result
if make regression >> "$LOG" 2>&1; then
    echo "[INFO] Test <AMS chip template with ihp-sg13g2> passed."
    RC=0
else
    echo "[ERROR] Test <AMS chip template with ihp-sg13g2> FAILED! Check the log file $LOG for details."
    RC=1
fi

# Clean up the cloned repository (keep the log for inspection)
cd "$TMP" || exit 1
rm -rf "$TMP/$REPO"

exit $RC
