#!/bin/bash
# SPDX-FileCopyrightText: 2026 Julian Schwarz and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# PEX bench of the open-pdks regression-test suite, all PDKs
# (https://github.com/iic-jku/open-pdks-regression-tests)
#
# Each PDK ships a set of metal-only dummy layouts whose parasitics follow from the PDK
# extraction deck by hand. They are extracted with Magic in all three modes and with the kpex
# 2.5D engine, and the values are compared against the expected results committed with the
# bench. The test fails when a new Magic, KLayout, kpex or PDK in the image extracts different
# numbers from unchanged layouts and an unchanged deck. See README.md.
#
# Only the verdict is printed on the console; the per-case results and the full command output
# go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

WORKDIR=${RUNS_DIR}/${RAND}/35
LOG=$WORKDIR/pex_bench_test.log
REPO=open-pdks-regression-tests
PDKS="ihp-sg13g2 ihp-sg13cmos5l gf180mcuD sky130A"
SUITE="PEX bench, all PDKs"

mkdir -p "$WORKDIR"
: > "$LOG"

PASS=0
FAIL=0

# All tests of the suite run in parallel and share one console, so a test may only report
# its verdict there. Per-case results go into the log; set SAK_TEST_VERBOSE=1 to get them on
# the console while debugging a regression.
VERBOSE=${SAK_TEST_VERBOSE:-0}

# report the result of one case: always to the log, to the console only if the case failed
# or verbose mode is on
report() {
    local line=$1
    local failed=$2
    echo "$line" >> "$LOG"
    if [ "$failed" -ne 0 ] || [ "$VERBOSE" -ne 0 ]; then
        echo "$line"
    fi
}

# One entry per PDK for the verdict line, in the order the PDKs run
PDK_RESULTS=""
add_result() {
    PDK_RESULTS="${PDK_RESULTS:+$PDK_RESULTS, }$1 $2"
}

# Read one variable out of a bench Makefile, including computed or conditional ones
bench_var() {
    make -C "$1" --no-print-directory --eval="print-%: ; @echo \$(\$*)" "print-$2" 2>/dev/null | tail -1
}

# What a failed case lifts onto the console, so the log only has to be opened for details.
# The detail lines are capped, since a tool update can move dozens of values at once; the
# verdict lines are not, so the line naming the kind of failure is never cut off.
DETAIL_RE='FAILED|^\[CHECK\] (DRIFT|MISSING)|^make(\[[0-9]+\])?: \*\*\*'
VERDICT_RE='^\[CHECK\] ([0-9]+ ok|DECK|TOOL|INCOMPLETE)|^\[ERROR\]'
DETAIL_MAX=8

highlight() {
    local out=$1 n
    n=$(grep -cE "$DETAIL_RE" "$out" 2>/dev/null) || n=0
    if [ "$n" -gt 0 ]; then
        grep -E "$DETAIL_RE" "$out" | head -"$DETAIL_MAX" | sed 's/^/[INFO]     /'
        if [ "$n" -gt "$DETAIL_MAX" ]; then
            echo "[INFO]     ... and $((n - DETAIL_MAX)) more like it, see $LOG"
        fi
    fi
    grep -E "$VERDICT_RE" "$out" | sed 's/^/[INFO]     /'
}

# Run one test case and compare the exit code against the expected one. A build or
# extraction step has one way to fail; the value check encodes what moved in its exit code
# (see scripts/check_results.py in the bench), so that one is decoded.
_run() {
    local kind=$1 name=$2 expect=$3
    shift 3
    local out=$WORKDIR/.case.out
    {
        echo "===================================================================="
        echo "==== TEST: $name (expect exit $expect)"
        echo "==== CMD : $*"
    } >> "$LOG"
    "$@" > "$out" 2>&1
    local rc=$?
    cat "$out" >> "$LOG"
    echo "==== EXIT: $rc" >> "$LOG"
    if [ "$rc" -eq "$expect" ]; then
        PASS=$((PASS+1))
        report "[PASS] $name" 0
        return
    fi
    local reason=ERROR
    if [ "$kind" = VALUES ]; then
        case $rc in
            1) reason=DECK ;;
            2) reason=DRIFT ;;
            3) reason=MISSING ;;
            4) reason=USAGE ;;
        esac
    fi
    # the first failure of a PDK is its verdict, not whatever it dragged down afterwards
    if [ "$PDK_VERDICT" = pass ]; then
        if [ "$kind" = VALUES ]; then
            PDK_VERDICT=$reason
        else
            PDK_VERDICT="failed at ${name#*: }"
        fi
    fi
    FAIL=$((FAIL+1))
    report "[FAIL] $name ($reason, exit $rc, expected $expect)" 1
    highlight "$out"
}

check()        { _run STEP   "$@"; }
check_values() { _run VALUES "$@"; }

# ============================================================================
# clone the benches
# ============================================================================

cd "$WORKDIR" || exit 1

# Clone the main branch of the open-pdks regression tests (incl. submodules)
if ! git clone --depth 1 --recursive --shallow-submodules --branch main \
        https://github.com/iic-jku/"$REPO".git "$REPO" >> "$LOG" 2>&1; then
    echo "[ERROR] Test <$SUITE> FAILED! Could not clone the repository. Check the log file $LOG for details."
    exit 1
fi

# Allow git to operate on this repo even if the dir owner differs from the
# container user (avoids "detected dubious ownership")
git config --global --add safe.directory "$WORKDIR/$REPO"

# ============================================================================
# run the bench of every PDK
# ============================================================================

# Each bench switches its PDK itself (its Makefile calls sak-pdk), so unlike test 25 this test
# does not source sak-pdk-script.sh. A failing step does not stop the other steps of that PDK,
# and a failing PDK does not stop the others.
for PDK_NAME in $PDKS; do
    BENCH=$WORKDIR/$REPO/$PDK_NAME/pex_bench
    PDK_VERDICT=pass
    PDK_NOTE=""

    if [ ! -f "$BENCH/Makefile" ]; then
        FAIL=$((FAIL+1))
        report "[FAIL] $PDK_NAME: no pex_bench/Makefile in $REPO" 1
        add_result "$PDK_NAME" "no bench"
        continue
    fi

    # build the layouts from the generators, so the extraction runs on what the code produces
    check        "$PDK_NAME: layouts generated"     0 make -C "$BENCH" layouts

    # Which engines a PDK can run is the bench's own statement in PEX_ENGINES. An engine the
    # PDK's tooling cannot run on an unmodified image is not called at all, instead of failing
    # every run.
    engines=$(bench_var "$BENCH" PEX_ENGINES)
    [ -n "$engines" ] || engines="magic kpex25"

    check        "$PDK_NAME: Magic modes 1/2/3"     0 make -C "$BENCH" pex-bench-magic
    case " $engines " in
        *" kpex25 "*)
            check "$PDK_NAME: kpex 2.5D"             0 make -C "$BENCH" pex-bench-2.5d ;;
        *)
            PDK_NOTE=" (no kpex)"
            echo "[INFO] $PDK_NAME: kpex25 is not in PEX_ENGINES, kpex 2.5D not called." >> "$LOG" ;;
    esac

    # tables A to I, which also writes runs/results.json
    check        "$PDK_NAME: tables"                0 make -C "$BENCH" pex-bench-compare

    # the value check, called directly because make would flatten its exit code to 2
    check_values "$PDK_NAME: values match expected" 0 \
        python3 "$BENCH/scripts/check_results.py" \
                "$BENCH/runs/results.json" "$BENCH/expected/results.json"

    add_result "$PDK_NAME" "$PDK_VERDICT$PDK_NOTE"
done

# ============================================================================
# summary
# ============================================================================

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <$SUITE> FAILED! $PDK_RESULTS ($PASS checks passed, $FAIL failed). Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <$SUITE> passed. $PDK_RESULTS ($PASS checks)."
    exit 0
fi
