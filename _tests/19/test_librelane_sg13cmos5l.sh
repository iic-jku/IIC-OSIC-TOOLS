#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test LibreLane for IHP-SG13CMOS5L

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

if command -v librelane >/dev/null 2>&1; then
    LOG=${RUNS_DIR}/${RAND}/19/result_ll_sg13cmos5l.log
    STDERR_LOG=${RUNS_DIR}/${RAND}/19/result_ll_sg13cmos5l.stderr.log
    WORKDIR=${RUNS_DIR}/${RAND}/19
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to ihp-sg13cmos5l PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh ihp-sg13cmos5l sg13cmos5l_stdcell > /dev/null
    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    find "$DIR" -maxdepth 1 -type f -exec cp {} "$WORKDIR" \;
    librelane --manual-pdk "$WORKDIR/counter.json" > "$LOG" 2> "$STDERR_LOG"
    LL_RC=$?

    # Grepping the stdout log for "ERROR" is not enough on its own. A step that
    # dies from an uncaught exception prints its traceback on stderr, leaves no
    # "ERROR" in the stdout log, and the run's own error.log stays empty -- so
    # this test reported "passed" over a flow that crashed in
    # OpenROAD.IRDropReport, the LAST step, where everything before it looks
    # perfect (gzipped Liberty, see install_eda.sh). Check the exit code, both
    # logs, and that the flow actually reached its end.
    FAILED=""
    [ "$LL_RC" -eq 0 ] || FAILED="librelane exited with $LL_RC"
    if [ -z "$FAILED" ] && grep -q "ERROR" "$LOG"; then
        FAILED="ERROR in the stdout log"
    fi
    if [ -z "$FAILED" ] && grep -q "Traceback (most recent call last)" "$STDERR_LOG"; then
        FAILED="Python traceback in the stderr log"
    fi
    # The Classic flow writes final/metrics.json only after its last step, so a
    # missing one means the run stopped early no matter how quiet it was.
    if [ -z "$FAILED" ] && \
        [ -z "$(find "$WORKDIR/runs" -maxdepth 3 -path "*/final/metrics.json" -print -quit 2>/dev/null)" ]; then
        FAILED="the flow produced no final/metrics.json"
    fi

    if [ -n "$FAILED" ]; then
        echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13cmos5l> FAILED ($FAILED). Check the logs <$LOG> and <$STDERR_LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with ihp-sg13cmos5l> passed."
        exit 0
    fi
else
    echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13cmos5l> FAILED. LibreLane is not installed!"
    exit 1
fi
