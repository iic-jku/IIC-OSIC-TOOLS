#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke/regression test of the KLayout PCells of all supported PDKs.
#
# For every PDK (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l) this test
# loads the PDK's KLayout PCell libraries and instantiates every PCell once
# with its default parameters, then flags empty cells (no geometry) and thrown
# errors. The heavy lifting is done by check_pcells.py, which also compares the
# outcome against a pinned per-PDK baseline; this wrapper drives it per PDK and
# aggregates the verdicts.
#
# A few PCells are DIRTY (empty) on purpose in the current PDKs; check_pcells.py
# pins them so the test is green now yet fails on any regression. See README.md.
#
# Only the verdict is printed on the console; the per-PDK results and the full
# KLayout output go into the log. Set PCELL_TEST_VERBOSE=1 to see every PCell.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_docker_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/27
LOG=$WORKDIR/klayout_pcells_test.log
HARNESS=$DIR/check_pcells.py
mkdir -p "$WORKDIR"
: > "$LOG"

if ! command -v klayout > /dev/null 2>&1; then
    echo "[ERROR] Test <KLayout PCells regression> FAILED! <klayout> not found. Check the log file $LOG for details."
    exit 1
fi

PASS=0
FAIL=0

# All tests of the suite run in parallel and share one console, so a test may
# only report its verdict there. Per-PDK results go into the log; set
# PCELL_TEST_VERBOSE=1 to get them on the console while debugging a regression.
VERBOSE=${PCELL_TEST_VERBOSE:-0}

report() {
    local line=$1
    local failed=$2
    echo "$line" >> "$LOG"
    if [ "$failed" -ne 0 ] || [ "$VERBOSE" -ne 0 ]; then
        echo "$line"
    fi
}

# Run the PCell harness for one PDK. Each PDK runs in a subshell so the PDK
# environment (PDK, PDKPATH, KLAYOUT_PATH, ...) does not leak into the next one,
# and in its own writable work dir because the gdsfactory-based sky130A and
# gf180mcuD PCells write a temporary GDS into the current directory.
check_pdk() {
    local pdk=$1
    local pdk_work=$WORKDIR/$pdk
    mkdir -p "$pdk_work"

    {
        echo "===================================================================="
        echo "==== PDK: $pdk"
    } >> "$LOG"

    (
        cd "$pdk_work" || exit 1
        # shellcheck source=/dev/null
        source sak-pdk-script.sh "$pdk" > /dev/null 2>&1
        klayout -zz -r "$HARNESS"
    ) >> "$LOG" 2>&1
    local rc=$?

    echo "==== EXIT: $rc" >> "$LOG"
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS+1))
        report "[PASS] $pdk PCells" 0
    else
        FAIL=$((FAIL+1))
        report "[FAIL] $pdk PCells (exit $rc, see log)" 1
    fi
}

for pdk in sky130A gf180mcuD ihp-sg13g2 ihp-sg13cmos5l; do
    check_pdk "$pdk"
done

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <KLayout PCells regression> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <KLayout PCells regression> passed ($PASS PDKs)."
    exit 0
fi
