#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test sak-current-density.py on small SG13G2 layouts whose currents are known by hand: wire and via ratios and the
# IR drop of the resistive solve, the floor and the screen, a black-box macro with a current view, a stale view, a
# macro checked on its own, and the exit codes.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/69

mkdir -p "$WORKDIR"

if [ -n "${DEBUG:-}" ]; then
    python3 "$DIR"/current_density_cases.py "$WORKDIR"
else
    python3 "$DIR"/current_density_cases.py "$WORKDIR" > "$WORKDIR"/cases.log 2>&1
fi
ERROR=$?

if [ $ERROR -ne 0 ]; then
    [ -z "${DEBUG:-}" ] && grep '\[ERROR\]' "$WORKDIR"/cases.log
    echo "[ERROR] Test <sak-current-density.py with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-current-density.py with ihp-sg13g2> passed."
    exit 0
fi
