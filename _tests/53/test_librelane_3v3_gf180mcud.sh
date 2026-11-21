#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run the LibreLane smoke test of test 04 with the 3.3V standard cells gf180mcu_as_sc_mcu7t3v3 of gf180mcuD.
# ciel installs them only on request (see install_ciel.sh).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

SCL=gf180mcu_as_sc_mcu7t3v3
TEST_NAME="LibreLane smoke-test with gf180mcuD and $SCL"

if command -v librelane >/dev/null 2>&1; then
    WORKDIR=${RUNS_DIR}/${RAND}/53
    LOG=$WORKDIR/result_ll_3v3_gf180mcud.log
    STDERR_LOG=$WORKDIR/result_ll_3v3_gf180mcud.stderr.log
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=/dev/null
    source sak-pdk-script.sh gf180mcuD "$SCL" > /dev/null

    mkdir -p "$WORKDIR"
    FAILED=""
    [ -d "$PDK_ROOT/$PDK/libs.ref/$SCL" ] || FAILED="$SCL is not installed in $PDK_ROOT/$PDK"

    if [ -z "$FAILED" ]; then
        find "$DIR" -maxdepth 1 -type f -exec cp {} "$WORKDIR" \;
        librelane "$WORKDIR"/counter.json > "$LOG" 2> "$STDERR_LOG"
        LL_RC=$?
        [ "$LL_RC" -eq 0 ] || FAILED="librelane exited with $LL_RC"
    fi

    # The checks of test 04, which explains why the exit code alone is not enough
    if [ -z "$FAILED" ] && grep -q "ERROR" "$LOG"; then
        FAILED="ERROR in the stdout log"
    fi
    if [ -z "$FAILED" ] && grep -q "Traceback (most recent call last)" "$STDERR_LOG"; then
        FAILED="Python traceback in the stderr log"
    fi
    FINAL_DIR=$(find "$WORKDIR/runs" -maxdepth 2 -type d -name final -print -quit 2>/dev/null)
    if [ -z "$FAILED" ] && [ ! -f "$FINAL_DIR/metrics.json" ]; then
        FAILED="the flow produced no final/metrics.json"
    fi
    # A flow that fell back to another library would pass all of the above
    if [ -z "$FAILED" ] && ! grep -q "${SCL}__" "$FINAL_DIR/nl/counter.nl.v"; then
        FAILED="the final netlist has no $SCL cells"
    fi

    if [ -n "$FAILED" ]; then
        LOGS=""
        [ -f "$LOG" ] && LOGS=" Check the logs <$LOG> and <$STDERR_LOG>."
        echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED).$LOGS"
        exit 1
    else
        echo "[INFO] Test <$TEST_NAME> passed."
        exit 0
    fi
else
    echo "[ERROR] Test <$TEST_NAME> FAILED. LibreLane is not installed!"
    exit 1
fi
