#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test VACASK simulation with simple examples.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=/foss/designs/runs/${RAND}/16
RESULT=/foss/designs/runs/${RAND}/16/result_vacask.log

mkdir -p "$WORKDIR"

# Run the simulations
vacask --no-output --quiet-progress "$DIR/gilbert.sim" > "$RESULT" 2>&1 || ERROR=1
vacask --no-output --quiet-progress "$DIR/toplevel.sim" > "$RESULT" 2>&1 || ERROR=1

# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <VACASK> FAILED."
    exit 1
else
    echo "[INFO] Test <VACASK> passed."
fi

# Cleanup
rm -f -- *.raw *.py
exit 0
