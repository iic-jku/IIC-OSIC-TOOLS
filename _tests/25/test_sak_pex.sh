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
# positional auto-derive), the kpex 2.5D engine (-k, with -S/-R/-g), and checks
# that invalid combinations are caught with the documented exit codes. Netlist
# content is verified where deterministic (header, subcircuit wrapper, devices).
#
# The test data in this directory is derived from the standard cell libraries
# of the installed PDKs (see README.md).
#
# Set SAK_PEX=<path> to test a not-yet-installed version of the script.
#
# Only the verdict is printed on the console; the per-case results and the full
# command output go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/25
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
# kpex 2.5D engine (-k): ihp-sg13g2 matrix incl. the guard checks
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null 2>&1

D=$DIR/ihp-sg13g2
CELL=sg13g2_inv_1
W=$WORKDIR/kpex_ihp
mkdir -p "$W" "$W/gz" "$W/auto"
NL=$W/$CELL.pex.spice
gzip -c "$D/$CELL.gds" > "$W/gz/$CELL.gds.gz"
# the auto-derive lookup of the Magic engine finds the .mag first, kpex must take the GDS
cp "$D/$CELL.gds" "$D/$CELL.mag" "$W/auto/"

# kpex's PEX-LVS puts the substrate on one global net (sub! in the IHP PDKs), a port of the
# netlist unless a tap and a label name it otherwise. The inverter has its taps under VSS, so a
# Metal1 cell made here gives the sub! port: its wires sort before sub! and VSS, so that the
# port list wraps onto "+" lines with both on them, and each wire couples to VSS and sub!.
SUBTIE=$W/subtie.gds
python3 - "$SUBTIE" > /dev/null 2>&1 << 'EOF'
import sys
import klayout.db as db
ly = db.Layout()
ly.dbu = 0.001
top = ly.create_cell("subtie")
m1, m1_pin, m1_text = ly.layer(8, 0), ly.layer(8, 2), ly.layer(8, 25)
names = [f"a_long_wire_name_{i}" for i in range(1, 9)] + ["VSS"]
for i, name in enumerate(names):
    box = db.Box(0, i * 1000, 20000, i * 1000 + 300)
    top.shapes(m1).insert(box)
    top.shapes(m1_pin).insert(box)
    top.shapes(m1_text).insert(db.Text(name, db.Trans(db.Point(100, i * 1000 + 150))))
ly.write(sys.argv[1])
EOF
# a schematic with the wrong NMOS width, which the full-RC check of kpex must reject
cat > "$W/wrong_w.cdl" << EOF
.SUBCKT $CELL A VDD VSS Y
MN0 Y A VSS VSS sg13_lv_nmos w=1u l=0.13u
MP0 Y A VDD VDD sg13_lv_pmos w=1.12u l=0.13u
.ENDS
EOF
CDL=$PDK_ROOT/$PDK/libs.ref/sg13g2_stdcell/cdl/sg13g2_stdcell.cdl

# default C-coupled extraction plus netlist and cleanup checks
check "kpex ihp: default (C-coupled) GDS"     0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "kpex ihp: netlist starts with header"  0 bash -c "head -1 '$NL' | grep -q '^\* PEX produced on .* with m=2 and s=1 (kpex 2.5D: --mode CC --blackbox y)$'"
check "kpex ihp: netlist has .subckt $CELL"   0 bash -c "grep -qi '^\.subckt $CELL ' '$NL' && grep -qi '^\.ends $CELL$' '$NL'"
check "kpex ihp: netlist contains devices"    0 bash -c "grep -q 'created by KLayout-PEX' '$NL' && grep -q '^X.* sg13_lv_nmos ' '$NL' && grep -q '^X.* sg13_lv_pmos ' '$NL' && grep -q '^C' '$NL'"
check "kpex ihp: kpex log written"            0 bash -c "grep -q 'kpex extract' '$W/$CELL.pex.log'"
check "kpex ihp: no run dir leftover"         0 bash -c "! ls -d '$W'/.pextmp_kpex_* 2>/dev/null"
check "kpex ihp: no .tmp netlist leftover"    0 bash -c "[ ! -f '$NL.tmp' ]"

# PEX modes and reduction
check "kpex ihp: -m 1 (kpex --mode C)"        0 "$SAK" -k -m 1 -w "$W" "$D/$CELL.gds"
check "kpex ihp: -m 1 header notes --mode C"  0 bash -c "head -1 '$NL' | grep -q 'with m=1 and s=1 (kpex 2.5D: --mode C --blackbox y)'"
check "kpex ihp: -m 3 (kpex --mode RC)"       0 "$SAK" -k -m 3 -w "$W" "$D/$CELL.gds"
check "kpex ihp: -m 3 reduces with TICER"     0 bash -c "head -1 '$NL' | grep -q -- '--mode RC --reduce ticer --blackbox y' && grep -q '^R' '$NL'"
check "kpex ihp: -m 3 -R none"                0 "$SAK" -k -m 3 -R none -w "$W" "$D/$CELL.gds"
check "kpex ihp: -R none in header"           0 bash -c "head -1 '$NL' | grep -q -- '--reduce none'"
check "kpex ihp: -m 3 -R floating"            0 "$SAK" -k -m 3 -R floating -w "$W" "$D/$CELL.gds"

# subcircuit handling
check "kpex ihp: -n renames the subcircuit"   0 "$SAK" -k -n my_inv_pex -w "$W" "$D/$CELL.gds"
check "kpex ihp: .subckt/.ends my_inv_pex"    0 bash -c "grep -qi '^\.subckt my_inv_pex ' '$NL' && grep -qi '^\.ends my_inv_pex$' '$NL'"
check "kpex ihp: -s 0 run"                    0 "$SAK" -k -s 0 -w "$W" "$D/$CELL.gds"
check "kpex ihp: -s 0 strips .subckt/.ends"   0 bash -c "grep -q 'created by KLayout-PEX' '$NL' && ! grep -qiE '^\.(subckt|ends)' '$NL'"
check "kpex ihp: -s 0 keeps devices and caps" 0 bash -c "grep -q 'created by KLayout-PEX' '$NL' && grep -q '^X' '$NL' && grep -q '^C' '$NL'"

# schematic (-S): the full-RC check passes against the stdcell CDL and fails against a wrong one
check "kpex ihp: -m 3 -S stdcell CDL"         0 "$SAK" -k -m 3 -S "$CDL" -w "$W" "$D/$CELL.gds"
check "kpex ihp: -m 3 -S wrong schematic"     1 "$SAK" -k -m 3 -S "$W/wrong_w.cdl" -w "$W" "$D/$CELL.gds"
check "kpex ihp: failed run leaves no netlist" 0 bash -c "[ ! -f '$NL' ] && [ ! -f '$NL.tmp' ]"
check "kpex ihp: failed run keeps run dir"    0 bash -c "ls -d '$W'/.pextmp_kpex_${CELL}_* > /dev/null 2>&1"
rm -rf "$W"/.pextmp_kpex_*
check "kpex ihp: -m 2 wrong schematic warns"  0 bash -c "'$SAK' -k -m 2 -S '$W/wrong_w.cdl' -w '$W' '$D/$CELL.gds' | grep -q '^\[WARNING\] kpex found the extracted netlist inconsistent'"
check "kpex ihp: -m 2 CDL does not warn"      0 bash -c "'$SAK' -k -m 2 -S '$CDL' -w '$W' '$D/$CELL.gds' > '$W/cdl.out' && ! grep -q '^\[WARNING\] kpex found' '$W/cdl.out'"
check "kpex ihp: -d -m 3 -S wrong schematic"  1 "$SAK" -d -k -m 3 -S "$W/wrong_w.cdl" -w "$W" "$D/$CELL.gds"
rm -rf "$W"/.pextmp_kpex_*
check "kpex ihp: -d debug run"                0 "$SAK" -d -k -w "$W" "$D/$CELL.gds"
check "kpex ihp: -d run leaves no run dir"    0 bash -c "head -1 '$NL' | grep -q 'kpex 2.5D' && ! ls -d '$W'/.pextmp_kpex_* 2>/dev/null"

# substrate tie (-g)
SNL=$W/subtie.pex.spice
check "kpex ihp: subtie test cell made"       0 bash -c "[ -s '$SUBTIE' ]"
check "kpex ihp: subtie -m 3 -n (tie to VSS)" 0 "$SAK" -k -m 3 -n subtie_pex -w "$W" "$SUBTIE"
check "kpex ihp: tied port list on one line"  0 bash -c "grep -q '^\.SUBCKT subtie_pex .*a_long_wire_name_8 .*VSS' '$SNL' && ! grep -q '^+' '$SNL'"
check "kpex ihp: no sub! left"                0 bash -c "grep -q 'created by KLayout-PEX' '$SNL' && ! grep -v '^\*' '$SNL' | grep -q 'sub!'"
check "kpex ihp: no R/C from VSS to VSS"      0 bash -c "grep -q 'created by KLayout-PEX' '$SNL' && ! awk '/^[RrCc]/ && \$2 == \$3' '$SNL' | grep -q ."
check "kpex ihp: wires couple to VSS"         0 bash -c "[ \$(grep -c '^C.* VSS ' '$SNL') -ge 8 ]"
check "kpex ihp: header notes the tie"        0 bash -c "head -1 '$SNL' | grep -q 'substrate port sub! tied to VSS)$'"
check "kpex ihp: subtie -s 0 with tie"        0 "$SAK" -k -s 0 -w "$W" "$SUBTIE"
check "kpex ihp: -s 0 tie drops wrapped list" 0 bash -c "! grep -qiE '^(\.subckt|\.ends|\+)' '$SNL' && ! grep -v '^\*' '$SNL' | grep -q 'sub!'"
check "kpex ihp: subtie -g '' keeps sub!"     0 "$SAK" -k -g "" -w "$W" "$SUBTIE"
check "kpex ihp: sub! port kept"              0 bash -c "grep -A2 '^\.SUBCKT subtie ' '$SNL' | grep -q 'sub!'"
check "kpex ihp: subtie -g a_long_wire_name_1" 0 "$SAK" -k -g a_long_wire_name_1 -w "$W" "$SUBTIE"
check "kpex ihp: tie to another port net"     0 bash -c "head -1 '$SNL' | grep -q 'sub! tied to a_long_wire_name_1)$' && ! grep -v '^\*' '$SNL' | grep -q 'sub!'"

# input variants
check "kpex ihp: GDS.GZ input"                0 "$SAK" -k -w "$W/gz" "$W/gz/$CELL.gds.gz"
check "kpex ihp: gds.gz netlist written"      0 bash -c "grep -q 'created by KLayout-PEX' '$W/gz/$CELL.pex.spice' && grep -qi '^\.subckt $CELL ' '$W/gz/$CELL.pex.spice'"
check "kpex ihp: PEX on .klay.gds"            0 "$SAK" -k -w "$W" "$D/$CELL.klay.gds"
check "kpex ihp: netlist uses stripped name"  0 bash -c "grep -q 'created by KLayout-PEX' '$NL' && grep -qi '^\.subckt $CELL ' '$NL'"
check "kpex ihp: auto-derive takes the GDS"   0 bash -c "cd '$W/auto' && '$SAK' -k '$CELL' && grep -q 'created by KLayout-PEX' '$CELL.pex.spice' && grep -qi '^\.subckt $CELL ' '$CELL.pex.spice'"
check "kpex ihp: -w creates multi-level dir"  0 "$SAK" -k -w "$W/deep/a/b" "$D/$CELL.gds"
check "kpex ihp: nested netlist written"      0 bash -c "grep -q 'created by KLayout-PEX' '$W/deep/a/b/$CELL.pex.spice'"

# guard checks
check "kpex guard: MAG input"                 7 "$SAK" -k -w "$W" "$D/$CELL.mag"
check "kpex guard: -t with -k"                4 "$SAK" -k -t 5000 -w "$W" "$D/$CELL.gds"
check "kpex guard: -S without -k"             4 "$SAK" -S "$CDL" -w "$W" "$D/$CELL.gds"
check "kpex guard: -g without -k"             4 "$SAK" -g VSS -w "$W" "$D/$CELL.gds"
check "kpex guard: -R unknown reduction"      4 "$SAK" -k -m 3 -R fast -w "$W" "$D/$CELL.gds"
check "kpex guard: -S file not found"         2 "$SAK" -k -S "$W/does_not_exist.cdl" -w "$W" "$D/$CELL.gds"
check "kpex guard: -g net is no port"         1 "$SAK" -k -g no_such_net -w "$W" "$SUBTIE"
check "kpex guard: kpex netlist kept after it" 0 bash -c "grep -q 'created by KLayout-PEX' '$W/subtie.pex.spice.tmp' && [ ! -f '$W/subtie.pex.spice' ]"
check "kpex guard: -g names the substrate"    4 "$SAK" -k -g 'sub!' -w "$W" "$SUBTIE"
check "kpex guard: GDS has no such cell"      1 "$SAK" -k -w "$W" "$D/${CELL}_wrongtop.gds"
check "kpex guard: PDK unknown to kpex"       6 env PDK=sky130B "$SAK" -k -w "$W" "$D/$CELL.gds"
check "kpex guard: kpex not in PATH"          5 env PATH=/usr/bin:/bin "$SAK" -k -w "$W" "$D/$CELL.gds"
rm -rf "$W"/.pextmp_kpex_*

# ============================================================================
# kpex 2.5D engine (-k): ihp-sg13cmos5l, gf180mcuD, sky130A
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l > /dev/null 2>&1
D=$DIR/ihp-sg13cmos5l
CELL=sg13cmos5l_inv_1
W=$WORKDIR/kpex_cmos5l
mkdir -p "$W"
check "kpex cmos5l: default (C-coupled) GDS"  0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "kpex cmos5l: netlist has .subckt"      0 bash -c "grep -q 'created by KLayout-PEX' '$W/$CELL.pex.spice' && grep -qi '^\.subckt $CELL ' '$W/$CELL.pex.spice'"
check "kpex cmos5l: -m 3 full-RC"             0 "$SAK" -k -m 3 -w "$W" "$D/$CELL.gds"
check "kpex cmos5l: subtie (tie to VSS)"      0 "$SAK" -k -w "$W" "$SUBTIE"
check "kpex cmos5l: sub! tied to VSS"         0 bash -c "grep -q 'created by KLayout-PEX' '$W/subtie.pex.spice' && head -1 '$W/subtie.pex.spice' | grep -q 'substrate port sub! tied to VSS)$' && ! grep -v '^\*' '$W/subtie.pex.spice' | grep -q 'sub!'"

# the gf180mcuD inverter has no tap, so its substrate is the port SUB
# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD > /dev/null 2>&1
D=$DIR/gf180mcuD
CELL=gf180mcu_fd_sc_mcu7t5v0__inv_1
W=$WORKDIR/kpex_gf180
mkdir -p "$W"
check "kpex gf180: default (C-coupled) GDS"   0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "kpex gf180: SUB tied to VSS"           0 bash -c "grep -q 'created by KLayout-PEX' '$W/$CELL.pex.spice' && grep -qi '^\.subckt $CELL .*VSS' '$W/$CELL.pex.spice' && ! grep -v '^\*' '$W/$CELL.pex.spice' | grep -qw 'SUB'"
check "kpex gf180: -m 3 full-RC"              0 "$SAK" -k -m 3 -w "$W" "$D/$CELL.gds"
check "kpex gf180: full-RC netlist written"   0 bash -c "grep -q 'created by KLayout-PEX' '$W/$CELL.pex.spice' && head -1 '$W/$CELL.pex.spice' | grep -q -- '--mode RC --reduce ticer'"

# the sky130A inverter names its ground VGND, so the default -g VSS keeps the port sky130_gnd
# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > /dev/null 2>&1
D=$DIR/sky130A
CELL=sky130_fd_sc_hd__inv_1
W=$WORKDIR/kpex_sky130
mkdir -p "$W"
check "kpex sky130: default (C-coupled) GDS"  0 "$SAK" -k -w "$W" "$D/$CELL.gds"
check "kpex sky130: no VSS, sky130_gnd kept"  0 bash -c "grep -qi '^\.subckt $CELL .*sky130_gnd' '$W/$CELL.pex.spice'"
check "kpex sky130: -m 3 -g VGND"             0 "$SAK" -k -m 3 -g VGND -w "$W" "$D/$CELL.gds"
check "kpex sky130: sky130_gnd tied to VGND"  0 bash -c "grep -q 'created by KLayout-PEX' '$W/$CELL.pex.spice' && ! grep -v '^\*' '$W/$CELL.pex.spice' | grep -q 'sky130_gnd'"

# ============================================================================
# summary
# ============================================================================

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <sak-pex.sh regression> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <sak-pex.sh regression> passed ($PASS checks)."
    exit 0
fi
