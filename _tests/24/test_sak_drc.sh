#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke/regression test for sak-drc.sh.
#
# Runs Magic and KLayout DRC on a standard cell inverter in all supported
# PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l), covers the input
# variants (.gds/.mag/.klay.gds layouts, gzipped layouts, auto-derive), all
# three -l DRC levels incl. the per-level report gating, and checks that
# invalid combinations are caught with the documented exit codes.
#
# Some runs are expected DIRTY (exit 1) because a standard cell in isolation
# violates chip-level or row-level rules by design (see README.md). These
# cases prove that the violation detection works. If a PDK or tool update
# changes such a verdict, this test flags it so the baseline can be reviewed.
#
# Set SAK_DRC=<path> to test a not-yet-installed version of the script.
#
# Only the verdict is printed on the console; the per-case results and the full
# command output go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/24
LOG=$WORKDIR/sak_drc_test.log
mkdir -p "$WORKDIR"
: > "$LOG"

# allow testing a not-yet-installed script version, resolve to an absolute path
SAK_DRC=${SAK_DRC:-sak-drc.sh}
SAK=$(command -v "$SAK_DRC")
if [ -z "$SAK" ]; then
    echo "[ERROR] Test <sak-drc.sh regression> FAILED! <$SAK_DRC> not found. Check the log file $LOG for details."
    exit 1
fi

PASS=0
FAIL=0

# All tests of the suite run in parallel and share one console, so a test may
# only report its verdict there. Per-case results go into the log; set
# SAK_TEST_VERBOSE=1 to get them on the console while debugging a regression.
VERBOSE=${SAK_TEST_VERBOSE:-0}

# report the result of one case: always to the log, to the console only if the
# case failed or verbose mode is on
report() {
    local line=$1
    local failed=$2
    echo "$line" >> "$LOG"
    if [ "$failed" -ne 0 ] || [ "$VERBOSE" -ne 0 ]; then
        echo "$line"
    fi
}

# run one test case and compare the exit code against the expected one
check() {
    local name=$1
    local expect=$2
    shift 2
    {
        echo "===================================================================="
        echo "==== TEST: $name (expect exit $expect)"
        echo "==== CMD : $*"
    } >> "$LOG"
    "$@" >> "$LOG" 2>&1
    local rc=$?
    echo "==== EXIT: $rc" >> "$LOG"
    if [ "$rc" -eq "$expect" ]; then
        PASS=$((PASS+1))
        report "[PASS] $name" 0
    else
        FAIL=$((FAIL+1))
        report "[FAIL] $name (exit $rc, expected $expect)" 1
    fi
}

# ============================================================================
# ihp-sg13g2: full matrix incl. the guard checks
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null 2>&1

D=$DIR/ihp-sg13g2
CELL=sg13g2_inv_1
W=$WORKDIR/ihp
mkdir -p "$W" "$W/gz"

# gzipped layout variants are created at runtime
gzip -c "$D/$CELL.gds" > "$W/gz/$CELL.gds.gz"
gzip -c "$D/$CELL.mag" > "$W/gz/$CELL.mag.gz"
# file for the format guard check
echo "dummy" > "$W/bad.xyz"

# valid Magic runs (the inverter is DRC clean in ihp-sg13g2)
check "ihp: -m GDS"                        0 "$SAK" -m -w "$W" "$D/$CELL.gds"
check "ihp: magic report written"          0 bash -c "grep -q 'COUNT: 0' '$W/$CELL.magic.drc/$CELL.magic.drc.rpt'"
check "ihp: -m MAG"                        0 "$SAK" -m -w "$W" "$D/$CELL.mag"
check "ihp: -m GDS.GZ"                     0 "$SAK" -m -w "$W/gz" "$W/gz/$CELL.gds.gz"
check "ihp: -m MAG.GZ"                     0 "$SAK" -m -w "$W/gz" "$W/gz/$CELL.mag.gz"
check "ihp: gz temp files cleaned up"      0 bash -c "! ls '$W/gz'/*.drctmp.* 2>/dev/null"
check "ihp: -w creates multi-level dir"    0 "$SAK" -m -w "$W/deep/a/b" "$D/$CELL.gds"
check "ihp: -d debug run"                  0 "$SAK" -d -m -w "$W" "$D/$CELL.gds"
check "ihp: -f flatglob run"               0 "$SAK" -m -f '*' -w "$W" "$D/$CELL.gds"
check "ihp: -c clean rerun"                0 "$SAK" -m -c -w "$W" "$D/$CELL.gds"

# valid KLayout runs (macro and precheck are clean, regular adds the
# chip-level density checks that a single standard cell fails by design)
check "ihp: -k macro (default level)"      0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "ihp: klayout report written"        0 bash -c "ls '$W/$CELL.klayout.drc'/*.lyrdb > /dev/null 2>&1"
check "ihp: -k -l precheck"                0 "$SAK" -k -l precheck -w "$W" "$D/$CELL.gds"
check "ihp: -k -l regular reports density" 1 "$SAK" -k -l regular -w "$W" "$D/$CELL.gds"
check "ihp: -k GDS.GZ"                     0 "$SAK" -k -w "$W/gz" "$W/gz/$CELL.gds.gz"
check "ihp: -b runs both engines"          0 "$SAK" -b -w "$W" "$D/$CELL.gds"

# engine selection: the last -m/-k/-b flag wins
W2=$WORKDIR/ihp_lastflag
mkdir -p "$W2"
check "ihp: last engine flag wins (-k -m)" 0 "$SAK" -k -m -w "$W2" "$D/$CELL.gds"
check "ihp: (-k -m) ran Magic only"        0 bash -c "[ -f '$W2/$CELL.magic.drc/$CELL.magic.drc.rpt' ] && [ ! -d '$W2/$CELL.klayout.drc' ]"
check "ihp: last engine flag wins (-m -k)" 0 "$SAK" -m -k -w "$W2/k" "$D/$CELL.gds"
check "ihp: (-m -k) ran KLayout only"      0 bash -c "[ -d '$W2/k/$CELL.klayout.drc' ] && [ ! -d '$W2/k/$CELL.magic.drc' ]"

# positional auto-derive (the cellname is resolved against the current dir only)
mkdir -p "$W/auto"
cp "$D/$CELL.gds" "$W/auto/$CELL.gds"
check "ihp: auto-derive in current dir"    0 bash -c "cd '$W/auto'  && '$SAK' -m '$CELL'"

# KLayout-drawn layouts use the <cell>.klay.gds naming convention, the .klay marker is
# stripped for the cell name. The stored sg13g2_inv_1.klay.gds was saved by KLayout with
# library context, so it carries extra top cells ($$$CONTEXT_INFO$$$) that the GDS top
# cell guard must tolerate.
W3=$WORKDIR/ihp_klay
mkdir -p "$W3" "$W3/auto"
check "ihp: -m on .klay.gds"               0 "$SAK" -m -w "$W3" "$D/$CELL.klay.gds"
check "ihp: report uses stripped name"     0 bash -c "grep -q 'COUNT: 0' '$W3/$CELL.magic.drc/$CELL.magic.drc.rpt'"
check "ihp: -k on .klay.gds"               0 "$SAK" -k -w "$W3" "$D/$CELL.klay.gds"
cp "$D/$CELL.klay.gds" "$W3/auto/$CELL.klay.gds"
check "ihp: auto-derive finds .klay.gds"   0 bash -c "cd '$W3/auto' && '$SAK' -m '$CELL'"

# guard checks (invalid input combinations a designer should not use)
check "guard: no arguments"                3 "$SAK"
check "guard: nonexistent cellname"        2 "$SAK" -m does_not_exist_42
check "guard: unknown layout file format"  5 "$SAK" -m -w "$W" "$W/bad.xyz"
check "guard: unknown -l DRC level"        3 "$SAK" -k -l bogus -w "$W" "$D/$CELL.gds"
check "guard: -k with MAG layout"          5 "$SAK" -k -w "$W" "$D/$CELL.mag"
check "guard: -b with MAG falls back"      0 "$SAK" -b -w "$W" "$D/$CELL.mag"
check "guard: GDS top cell mismatch (-m)"  7 "$SAK" -m -w "$W" "$D/${CELL}_wrongtop.gds"
check "guard: GDS top cell mismatch (-k)"  7 "$SAK" -k -w "$W" "$D/${CELL}_wrongtop.gds"
check "guard: PDK_ROOT not set"            8 env PDK_ROOT= "$SAK" -m -w "$W" "$D/$CELL.gds"
check "guard: PDK not set"                 8 env PDK= "$SAK" -m -w "$W" "$D/$CELL.gds"
check "guard: PDKPATH not set"             8 env PDKPATH= "$SAK" -m -w "$W" "$D/$CELL.gds"
check "guard: unsupported PDK"             6 env PDK=nonexistent_pdk "$SAK" -m -w "$W" "$D/$CELL.gds"
check "guard: magic not in PATH"           4 env PATH=/usr/bin:/bin "$SAK" -m -w "$W" "$D/$CELL.gds"
check "guard: klayout not in PATH"         4 env PATH=/usr/bin:/bin "$SAK" -k -w "$W" "$D/$CELL.gds"

# ============================================================================
# ihp-sg13cmos5l
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l > /dev/null 2>&1

D=$DIR/ihp-sg13cmos5l
CELL=sg13cmos5l_inv_1
W=$WORKDIR/cmos5l
mkdir -p "$W"

check "cmos5l: -m GDS"                     0 "$SAK" -m -w "$W" "$D/$CELL.gds"
check "cmos5l: -k macro (default level)"   0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "cmos5l: -k -l precheck"             0 "$SAK" -k -l precheck -w "$W" "$D/$CELL.gds"
check "cmos5l: -k -l regular density"      1 "$SAK" -k -l regular -w "$W" "$D/$CELL.gds"
check "cmos5l: -b runs both engines"       0 "$SAK" -b -w "$W" "$D/$CELL.gds"

# ============================================================================
# gf180mcuD
# note: the isolated 5V standard cell violates the dualgate rules DF.13_MV
# and DF.14_MV (satisfied only by row composition), so every KLayout level
# reports errors. This is expected and proves the violation detection.
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD > /dev/null 2>&1

D=$DIR/gf180mcuD
CELL=gf180mcu_fd_sc_mcu7t5v0__inv_1
W=$WORKDIR/gf180
mkdir -p "$W"

check "gf180: -m GDS"                      0 "$SAK" -m -w "$W" "$D/$CELL.gds"
check "gf180: -k macro reports DF errors"  1 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "gf180: klayout report written"      0 bash -c "[ -f '$W/$CELL.klayout.drc/$CELL.lyrdb' ]"
check "gf180: -k -l precheck"              1 "$SAK" -k -l precheck -w "$W" "$D/$CELL.gds"
check "gf180: -k -l regular"               1 "$SAK" -k -l regular -w "$W" "$D/$CELL.gds"
check "gf180: -b combines the verdicts"    1 "$SAK" -b -w "$W" "$D/$CELL.gds"

# ============================================================================
# sky130A
# note: Magic DRC flags the missing-tap rules (nwell.4, LU.2, LU.3) on a
# standard cell in isolation (taps sit in separate tap cells), so -m is
# expected DIRTY. The KLayout decks are clean on this cell.
# note: Magic DRC on a .mag layout is also covered by test 02.
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > /dev/null 2>&1

D=$DIR/sky130A
CELL=sky130_fd_sc_hd__inv_1
W=$WORKDIR/sky130

# per-level runs in separate work dirs so the report gating can be asserted
mkdir -p "$W/pre" "$W/mac" "$W/reg"

check "sky130: -m GDS reports tap errors"  1 "$SAK" -m -w "$W" "$D/$CELL.gds"
check "sky130: -k -l precheck"             0 "$SAK" -k -l precheck -w "$W/pre" "$D/$CELL.gds"
check "sky130: precheck runs FEOL+BEOL"    0 bash -c "[ -f '$W/pre/$CELL.klayout.drc.feol.xml' ] && [ -f '$W/pre/$CELL.klayout.drc.beol.xml' ]"
check "sky130: precheck gates aux decks"   0 bash -c "[ ! -f '$W/pre/$CELL.klayout.drc.pincheck.xml' ] && [ ! -f '$W/pre/$CELL.klayout.drc.zeroarea.xml' ] && [ ! -f '$W/pre/$CELL.klayout.drc.density.xml' ]"
check "sky130: -k macro (default level)"   0 "$SAK" -k -w "$W/mac" "$D/$CELL.gds"
check "sky130: macro adds pin/zero-area"   0 bash -c "[ -f '$W/mac/$CELL.klayout.drc.pincheck.xml' ] && [ -f '$W/mac/$CELL.klayout.drc.zeroarea.xml' ]"
check "sky130: macro gates density"        0 bash -c "[ ! -f '$W/mac/$CELL.klayout.drc.density.xml' ]"
check "sky130: -k -l regular"              0 "$SAK" -k -l regular -w "$W/reg" "$D/$CELL.gds"
check "sky130: regular adds density"       0 bash -c "[ -f '$W/reg/$CELL.klayout.drc.density.xml' ]"
check "sky130: -b combines the verdicts"   1 "$SAK" -b -w "$W" "$D/$CELL.gds"

# ============================================================================
# summary
# ============================================================================

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <sak-drc.sh regression> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <sak-drc.sh regression> passed ($PASS checks)."
    exit 0
fi
