#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke/regression test for sak-lvs.sh.
#
# Runs Magic+Netgen and KLayout LVS on a known-good standard cell inverter in
# all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l), covers
# the input variants (SPICE/CDL netlist, .gds/.mag/.klay.gds layout, gzipped
# layouts, positional auto-derive), and checks that invalid combinations are caught
# with the documented exit codes.
#
# The test data in this directory is derived from the standard cell libraries
# of the installed PDKs (see README.md for how to regenerate it).
#
# Set SAK_LVS=<path> to test a not-yet-installed version of the script.
#
# Only the verdict is printed on the console; the per-case results and the full
# command output go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_docker_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/23
LOG=$WORKDIR/sak_lvs_test.log
mkdir -p "$WORKDIR"
: > "$LOG"

# allow testing a not-yet-installed script version, resolve to an absolute path
SAK_LVS=${SAK_LVS:-sak-lvs.sh}
SAK=$(command -v "$SAK_LVS")
if [ -z "$SAK" ]; then
    echo "[ERROR] Test <sak-lvs.sh regression> FAILED! <$SAK_LVS> not found. Check the log file $LOG for details."
    exit 1
fi

PASS=0
FAIL=0
KNOWN=0

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
# files for the format guard checks
echo "dummy" > "$W/bad.xyz"

# valid runs
check "ihp: -m SPICE + GDS"                0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "ihp: -k CDL + GDS"                  0 "$SAK" -k -s "$D/$CELL.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "ihp: -m SPICE + MAG"                0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.mag" -c "$CELL" -w "$W"
check "ihp: -m SPICE + GDS.GZ"             0 "$SAK" -m -s "$D/$CELL.spice" -l "$W/gz/$CELL.gds.gz" -c "$CELL" -w "$W/gz"
check "ihp: -m SPICE + MAG.GZ"             0 "$SAK" -m -s "$D/$CELL.spice" -l "$W/gz/$CELL.mag.gz" -c "$CELL" -w "$W/gz"
check "ihp: -k CDL + GDS.GZ"               0 "$SAK" -k -s "$D/$CELL.cdl"   -l "$W/gz/$CELL.gds.gz" -c "$CELL" -w "$W/gz"
check "ihp: gz temp files cleaned up"      0 bash -c "! ls '$W/gz'/*.lvstmp.* 2>/dev/null"
check "ihp: -w creates multi-level dir"    0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W/deep/a/b"
check "ihp: -d debug run"                  0 "$SAK" -d -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# engine fallback and selection
check "ihp: -b SPICE falls back to Magic"  0 "$SAK" -b -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "ihp: -b CDL falls back to KLayout"  0 "$SAK" -b -s "$D/$CELL.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "ihp: -b MAG falls back to Magic"    0 "$SAK" -b -s "$D/$CELL.spice" -l "$D/$CELL.mag" -c "$CELL" -w "$W"
check "ihp: last engine flag wins (-m -k)" 0 "$SAK" -m -k -s "$D/$CELL.cdl" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# positional auto-derive (the cellname is resolved against the current dir only)
mkdir -p "$W/auto"
cp "$D/$CELL.spice" "$W/auto/$CELL.spice"
cp "$D/$CELL.gds"   "$W/auto/$CELL.gds"
check "ihp: auto-derive in current dir"    0 bash -c "cd '$W/auto'  && '$SAK' -m '$CELL'"

# KLayout-drawn layouts use the <cell>.klay.gds naming convention. The stored
# sg13g2_inv_1.klay.gds was saved by KLayout with library context, so it carries an
# extra $$$CONTEXT_INFO$$$ top cell that the GDS top cell guard must tolerate.
W5=$WORKDIR/ihp_klay
mkdir -p "$W5" "$W5/auto"
check "ihp: -m with .klay.gds layout"      0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.klay.gds" -c "$CELL" -w "$W5"
check "ihp: magic report in run dir"       0 bash -c "grep -qi 'Circuits match uniquely' '$W5/$CELL.magic.lvs/$CELL.lvs.out'"
check "ihp: -k with .klay.gds layout"      0 "$SAK" -k -s "$D/$CELL.cdl"   -l "$D/$CELL.klay.gds" -c "$CELL" -w "$W5"
cp "$D/$CELL.spice"    "$W5/auto/$CELL.spice"
cp "$D/$CELL.klay.gds" "$W5/auto/$CELL.klay.gds"
check "ihp: auto-derive finds .klay.gds"   0 bash -c "cd '$W5/auto' && '$SAK' -m '$CELL'"

# reuse a netlist that already is the target file in the workdir (the script must not delete its own input)
cp "$D/$CELL.spice" "$W/${CELL}_magic.spice"
check "ihp: -s reuses netlist in workdir"  0 "$SAK" -m -s "$W/${CELL}_magic.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# LVS mismatch detection (broken netlists must FAIL with exit 1)
check "ihp: -m broken SPICE reports mismatch" 1 "$SAK" -m -s "$D/${CELL}_broken.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "ihp: -k broken CDL reports mismatch"   1 "$SAK" -k -s "$D/${CELL}_broken.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# guard checks (invalid input combinations a designer should not use)
check "guard: no arguments"                3 "$SAK"
check "guard: nonexistent cellname"        2 "$SAK" -m does_not_exist_42
check "guard: -s without -l and -c"        4 "$SAK" -s "$D/$CELL.spice"
check "guard: missing netlist file"        2 "$SAK" -m -s "$W/missing.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: unknown -s file format"      7 "$SAK" -m -s "$W/bad.xyz" -l "$D/$CELL.gds" -c "$CELL"
check "guard: unknown -l file format"      7 "$SAK" -m -s "$D/$CELL.spice" -l "$W/bad.xyz" -c "$CELL"
check "guard: -k with SPICE netlist"       7 "$SAK" -k -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "guard: -m with CDL netlist"         7 "$SAK" -m -s "$D/$CELL.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "guard: -k with MAG layout"          7 "$SAK" -k -s "$D/$CELL.cdl"   -l "$D/$CELL.mag" -c "$CELL" -w "$W"
check "guard: -k with Verilog netlist"     7 "$SAK" -k -s "$D/dummy.v"     -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "guard: GDS top cell name mismatch"  5 "$SAK" -m -s "$D/$CELL.spice" -l "$D/${CELL}_wrongtop.gds" -c "$CELL" -w "$W"
check "guard: PDK_ROOT not set"            4 env PDK_ROOT= "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: PDK not set"                 4 env PDK= "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: PDKPATH not set"             4 env PDKPATH= "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: STD_CELL_LIBRARY not set"    4 env STD_CELL_LIBRARY= "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: unsupported PDK"             6 env PDK=nonexistent_pdk "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"
check "guard: magic not in PATH"           8 env PATH=/usr/bin:/bin "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL"

# ============================================================================
# ihp-sg13cmos5l
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l > /dev/null 2>&1

D=$DIR/ihp-sg13cmos5l
CELL=sg13cmos5l_inv_1
W=$WORKDIR/cmos5l
mkdir -p "$W"

check "cmos5l: -m SPICE + GDS"             0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "cmos5l: -k CDL + GDS"               0 "$SAK" -k -s "$D/$CELL.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# ============================================================================
# gf180mcuD
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD > /dev/null 2>&1

D=$DIR/gf180mcuD
CELL=gf180mcu_fd_sc_mcu7t5v0__inv_1
W=$WORKDIR/gf180
mkdir -p "$W"

check "gf180: -m SPICE + GDS"              0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"
check "gf180: -k CDL + GDS"                0 "$SAK" -k -s "$D/$CELL.cdl"   -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# ============================================================================
# sky130A
# note: the Magic+Netgen run for a .sch schematic is covered by test 02
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > /dev/null 2>&1

D=$DIR/sky130A
CELL=sky130_fd_sc_hd__inv_1
W=$WORKDIR/sky130
mkdir -p "$W"

check "sky130: -m SPICE + GDS"             0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# KNOWN ISSUE: the sky130.lvs KLayout deck reads all schematic device classes
# upper-case while the layout classes are lower-case, so the compare never
# matches (checked with a hand-verified identical netlist). The run itself and
# the result handling of sak-lvs.sh are correct. Report this as known instead
# of failing, and celebrate when an updated PDK fixes it.
# see issue: https://github.com/fossi-foundation/open-pdks/issues/531
echo "==== TEST: sky130: -k CDL + GDS (known upstream deck issue)" >> "$LOG"
"$SAK" -k -s "$D/$CELL.cdl" -l "$D/$CELL.gds" -c "$CELL" -w "$W" >> "$LOG" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    PASS=$((PASS+1))
    # worth surfacing on the console: the known-issue handling can now be removed
    echo "[INFO] sky130: -k CDL + GDS passed, the upstream sky130.lvs deck got fixed."
elif [ "$rc" -eq 1 ]; then
    KNOWN=$((KNOWN+1))
    report "[KNOWN] sky130: -k reports mismatch due to the upstream sky130.lvs deck issue (not counted as failure)" 0
else
    FAIL=$((FAIL+1))
    report "[FAIL] sky130: -k CDL + GDS (exit $rc, expected 0 or the known mismatch 1)" 1
fi

# ============================================================================
# summary
# ============================================================================

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <sak-lvs.sh regression> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <sak-lvs.sh regression> passed ($PASS checks, $KNOWN known issue(s))."
    exit 0
fi
