#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke/regression test for sak-pex.sh.
#
# Runs PEX on a standard cell inverter in all supported PDKs (sky130A,
# gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l), covers all PEX modes (C-decoupled,
# C-coupled, full-RC incl. the -t/-r/-y extresist overrides), the subcircuit
# handling (-s/-n), the input variants (.mag/.gds/.klay.gds, gzipped layouts,
# positional auto-derive), and checks that invalid combinations are caught with the
# documented exit codes. Netlist content is verified where deterministic
# (header, subcircuit wrapper, devices).
#
# The test data in this directory is derived from the standard cell libraries
# of the installed PDKs (see README.md).
#
# Set SAK_PEX=<path> to test a not-yet-installed version of the script.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=/foss/designs/runs/${RAND}/25
LOG=$WORKDIR/sak_pex_test.log
mkdir -p "$WORKDIR"
: > "$LOG"

# allow testing a not-yet-installed script version, resolve to an absolute path
SAK_PEX=${SAK_PEX:-sak-pex.sh}
SAK=$(command -v "$SAK_PEX")
if [ -z "$SAK" ]; then
    echo "[ERROR] Test <sak-pex.sh regression> FAILED! <$SAK_PEX> not found. Check the log file $LOG for details."
    exit 1
fi

PASS=0
FAIL=0

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
        echo "[PASS] $name"
    else
        FAIL=$((FAIL+1))
        echo "[FAIL] $name (exit $rc, expected $expect)"
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

# default C-coupled extraction plus netlist and cleanup checks
check "ihp: default (C-coupled) GDS"       0 "$SAK" -w "$W" "$D/$CELL.gds"
NL=$W/$CELL.pex.spice
check "ihp: netlist starts with header"    0 bash -c "head -1 '$NL' | grep -q '^\* PEX produced on'"
check "ihp: netlist has .subckt $CELL"     0 bash -c "grep -qi '^\.subckt $CELL ' '$NL'"
check "ihp: netlist contains devices"      0 bash -c "grep -q '^X0 ' '$NL' && grep -q '^C0 ' '$NL'"
check "ihp: no .ext leftovers"             0 bash -c "! ls '$W'/*.ext 2>/dev/null"
check "ihp: no .tmp netlist leftover"      0 bash -c "[ ! -f '$NL.tmp' ]"
check "ihp: no tcl script leftover"        0 bash -c "! ls '$W'/pex_*.tcl 2>/dev/null"
check "ihp: magic log written"             0 bash -c "[ -s '$W/$CELL.pex.log' ]"

# PEX modes
check "ihp: -m 1 C-decoupled"              0 "$SAK" -m 1 -w "$W" "$D/$CELL.gds"
check "ihp: -m 1 header notes m=1"         0 bash -c "head -1 '$NL' | grep -q 'with m=1'"
check "ihp: -m 3 full-RC"                  0 "$SAK" -m 3 -w "$W" "$D/$CELL.gds"
check "ihp: -m 3 header notes extresist"   0 bash -c "head -1 '$NL' | grep -q 'extresist threshold'"
check "ihp: -m 3 no .nodes/.sim leftovers" 0 bash -c "! ls '$W'/*.nodes '$W'/*.sim 2>/dev/null"
check "ihp: -m 3 with -t/-r/-y overrides"  0 "$SAK" -m 3 -t 5000 -r 500 -y 2 -w "$W" "$D/$CELL.gds"
check "ihp: custom extresist in header"    0 bash -c "head -1 '$NL' | grep -q 'threshold=5000 mOhm, minres=500 mOhm, mindelay=2 ps'"
check "ihp: repeated flag, last wins"      0 "$SAK" -m 1 -m 2 -w "$W" "$D/$CELL.gds"
check "ihp: last-wins header notes m=2"    0 bash -c "head -1 '$NL' | grep -q 'with m=2'"

# subcircuit handling
check "ihp: -s 0 run"                      0 "$SAK" -s 0 -w "$W" "$D/$CELL.gds"
check "ihp: -s 0 strips .subckt/.ends"     0 bash -c "! grep -qiE '^\.(subckt|ends)' '$NL'"
check "ihp: -s 0 keeps devices and caps"   0 bash -c "grep -q '^X0 ' '$NL' && grep -q '^C0 ' '$NL'"
check "ihp: -n renames the subcircuit"     0 "$SAK" -n my_inv_pex -w "$W" "$D/$CELL.gds"
check "ihp: .subckt is my_inv_pex"         0 bash -c "grep -qi '^\.subckt my_inv_pex ' '$NL'"
check "ihp: -s 0 -n combined"              0 "$SAK" -s 0 -n my_inv_pex -w "$W" "$D/$CELL.gds"
check "ihp: -s 0 -n has no wrapper"        0 bash -c "! grep -qi '^\.subckt' '$NL'"

# input variants
check "ihp: MAG input"                     0 "$SAK" -w "$W" "$D/$CELL.mag"
check "ihp: MAG.GZ input"                  0 "$SAK" -w "$W/gz" "$W/gz/$CELL.mag.gz"
check "ihp: mag.gz temp dir cleaned"       0 bash -c "! ls -d '$W/gz'/.pextmp_* 2>/dev/null"
check "ihp: GDS.GZ input"                  0 "$SAK" -w "$W/gz" "$W/gz/$CELL.gds.gz"
check "ihp: gds.gz temp file cleaned"      0 bash -c "[ ! -f '$W/gz/$CELL.pextmp.gds' ]"
check "ihp: -w creates multi-level dir"    0 "$SAK" -w "$W/deep/a/b" "$D/$CELL.gds"
check "ihp: nested netlist written"        0 bash -c "[ -f '$W/deep/a/b/$CELL.pex.spice' ]"
check "ihp: -d debug run"                  0 "$SAK" -d -w "$W" "$D/$CELL.gds"

# positional auto-derive (the cellname is resolved against the current dir only)
mkdir -p "$W/auto"
cp "$D/$CELL.gds" "$W/auto/$CELL.gds"
check "ihp: auto-derive in current dir"    0 bash -c "cd '$W/auto'  && '$SAK' '$CELL'"

# KLayout-drawn layouts use the <cell>.klay.gds naming convention, the .klay marker is
# stripped for the cell name. The stored sg13g2_inv_1.klay.gds was saved by KLayout with
# library context, so it carries an extra $$$CONTEXT_INFO$$$ top cell that the GDS top
# cell guard must tolerate.
W4=$WORKDIR/ihp_klay
mkdir -p "$W4" "$W4/auto"
check "ihp: PEX on .klay.gds"              0 "$SAK" -w "$W4" "$D/$CELL.klay.gds"
check "ihp: netlist uses stripped name"    0 bash -c "grep -qi '^\.subckt $CELL ' '$W4/$CELL.pex.spice'"
cp "$D/$CELL.klay.gds" "$W4/auto/$CELL.klay.gds"
check "ihp: auto-derive finds .klay.gds"   0 bash -c "cd '$W4/auto' && '$SAK' '$CELL'"

# guard checks (invalid input combinations a designer should not use)
check "guard: no arguments"                3 "$SAK"
check "guard: flags but no cellname"       3 "$SAK" -m 1 -w "$W"
check "guard: nonexistent cellname"        2 "$SAK" -w "$W" does_not_exist_42
check "guard: -m 0 out of range"           4 "$SAK" -m 0 -w "$W" "$D/$CELL.gds"
check "guard: -m 4 out of range"           4 "$SAK" -m 4 -w "$W" "$D/$CELL.gds"
check "guard: -m not an integer"           4 "$SAK" -m abc -w "$W" "$D/$CELL.gds"
check "guard: -s 2 out of range"           4 "$SAK" -s 2 -w "$W" "$D/$CELL.gds"
check "guard: -t not an integer"           4 "$SAK" -t abc -w "$W" "$D/$CELL.gds"
check "guard: -y negative"                 4 "$SAK" -y -1 -w "$W" "$D/$CELL.gds"
check "guard: unknown layout file format"  7 "$SAK" -w "$W" "$W/bad.xyz"
check "guard: GDS top cell mismatch"       1 "$SAK" -w "$W" "$D/${CELL}_wrongtop.gds"
check "guard: PDK_ROOT not set"            8 env PDK_ROOT= "$SAK" -w "$W" "$D/$CELL.gds"
check "guard: PDK not set"                 8 env PDK= "$SAK" -w "$W" "$D/$CELL.gds"
check "guard: PDKPATH not set"             8 env PDKPATH= "$SAK" -w "$W" "$D/$CELL.gds"
check "guard: unsupported PDK"             6 env PDK=nonexistent_pdk "$SAK" -w "$W" "$D/$CELL.gds"
check "guard: magic not in PATH"           5 env PATH=/usr/bin:/bin "$SAK" -w "$W" "$D/$CELL.gds"

# ============================================================================
# ihp-sg13cmos5l
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l > /dev/null 2>&1

D=$DIR/ihp-sg13cmos5l
CELL=sg13cmos5l_inv_1
W=$WORKDIR/cmos5l
mkdir -p "$W"

check "cmos5l: default (C-coupled) GDS"    0 "$SAK" -w "$W" "$D/$CELL.gds"
check "cmos5l: netlist has .subckt"        0 bash -c "grep -qi '^\.subckt $CELL ' '$W/$CELL.pex.spice'"
check "cmos5l: -m 3 full-RC"               0 "$SAK" -m 3 -w "$W" "$D/$CELL.gds"

# ============================================================================
# gf180mcuD
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD > /dev/null 2>&1

D=$DIR/gf180mcuD
CELL=gf180mcu_fd_sc_mcu7t5v0__inv_1
W=$WORKDIR/gf180
mkdir -p "$W"

check "gf180: default (C-coupled) GDS"     0 "$SAK" -w "$W" "$D/$CELL.gds"
check "gf180: netlist has .subckt"         0 bash -c "grep -qi '^\.subckt $CELL ' '$W/$CELL.pex.spice'"

# ============================================================================
# sky130A
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > /dev/null 2>&1

D=$DIR/sky130A
CELL=sky130_fd_sc_hd__inv_1
W=$WORKDIR/sky130
mkdir -p "$W"

check "sky130: default (C-coupled) GDS"    0 "$SAK" -w "$W" "$D/$CELL.gds"
check "sky130: netlist has .subckt"        0 bash -c "grep -qi '^\.subckt $CELL ' '$W/$CELL.pex.spice'"
check "sky130: -m 3 full-RC"               0 "$SAK" -m 3 -w "$W" "$D/$CELL.gds"

# ============================================================================
# summary
# ============================================================================

echo "--------------------------------------------------------------------"
echo "[INFO] sak-pex.sh regression: $PASS passed, $FAIL failed. Log: $LOG"
if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <sak-pex.sh regression> FAILED! Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <sak-pex.sh regression> passed."
    exit 0
fi
