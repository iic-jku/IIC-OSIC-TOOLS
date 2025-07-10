#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test VACASK simulation with simple examples.

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the simulations
vacask --no-output --quiet-progress $DIR/gilbert.sim > /dev/null 2>&1 || ERROR=1
vacask --no-output --quiet-progress $DIR/toplevel.sim > /dev/null 2>&1 || ERROR=1

# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <VACASK> FAILED."
    exit 1
else
    echo "[INFO] Test <VACASK> passed."
fi

# Cleanup
rm -f *.raw *.py
exit 0
