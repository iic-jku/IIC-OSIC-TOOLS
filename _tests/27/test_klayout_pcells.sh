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

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
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

# Resident-memory ceiling for one klayout run, in KiB (see check_pdk below).
# 8 GiB is far above what any well-behaved PCell of the four PDKs needs.
#
# Note this is deliberately *not* `ulimit -v`: that caps the virtual address
# space, and OpenBLAS (pulled in via numpy by the gdsfactory-based sky130A and
# gf180mcuD PCells) reserves large per-thread arenas up front. On a machine with
# many cores those reservations alone exceed any sane limit and KLayout dies
# with "OpenBLAS error: Memory allocation still failed after 10 retries" before
# instantiating a single PCell.
RSS_LIMIT_KB=${PCELL_TEST_RSS_LIMIT_KB:-8388608}

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

        # Watch the resident memory of the harness and kill it if it runs away.
        # The PCells known to do so are skipped by check_pcells.py itself (see
        # its "runaway" lists); this is the backstop for a new one. Without it,
        # such a PCell grows until the *kernel* OOM-kills klayout -- observed
        # past 15 GB with gf180mcuD -- which loses the verdict for the whole PDK
        # and starves the tests running next to this one in the suite.
        klayout -zz -r "$HARNESS" &
        klayout_pid=$!
        (
            while kill -0 "$klayout_pid" 2> /dev/null; do
                rss=$(ps -o rss= -p "$klayout_pid" 2> /dev/null | tr -d ' ')
                if [ -n "$rss" ] && [ "$rss" -gt "$RSS_LIMIT_KB" ]; then
                    echo "[HARNESS] killing klayout: resident memory ${rss} KiB exceeds ${RSS_LIMIT_KB} KiB"
                    kill -9 "$klayout_pid" 2> /dev/null
                    break
                fi
                sleep 2
            done
        ) &
        watchdog_pid=$!
        wait "$klayout_pid"
        klayout_rc=$?
        kill "$watchdog_pid" 2> /dev/null
        exit $klayout_rc
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
