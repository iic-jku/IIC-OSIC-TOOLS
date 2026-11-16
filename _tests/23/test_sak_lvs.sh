#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke/regression test for sak-lvs.sh.
#
# Runs Magic+Netgen and KLayout LVS on a known-good standard cell inverter in
# all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l), covers
# the input variants (xschem schematic, SPICE/CDL/Verilog netlist, .gds/.mag/
# .klay.gds layout, gzipped layouts, positional auto-derive), checks in every
# PDK and with both engines that each class of error between netlist and layout
# is reported (wrong device parameters, wrong model, wrong connections, missing
# device, renamed port), and that invalid combinations are caught with the
# documented exit codes.
#
# The test data in this directory is derived from the standard cell libraries
# of the installed PDKs (see README.md for how to regenerate it).
#
# Set SAK_LVS=<path> to test a not-yet-installed version of the script.
#
# Only the verdict is printed on the console; the per-case results and the full
# command output go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
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

# copy a netlist or schematic with one deliberate error, an unchanged copy is a failed case
#   swap: drain and gate of the first device, short: its gate to its source, del: second device,
#   port: rename port <arg>, other kinds: apply the sed expression <arg>
mutate() {
    local kind=$1
    local in=$2
    local out=$3
    local arg=$4
    case $kind in
        swap)  awk '/^[XM]/ { n++; if (n == 1) { t = $2; $2 = $3; $3 = t } } { print }' "$in" > "$out" ;;
        short) awk '/^[XM]/ { n++; if (n == 1) { $3 = $4 } } { print }' "$in" > "$out" ;;
        del)   awk '/^[XM]/ { n++; if (n == 2) next } { print }' "$in" > "$out" ;;
        port)  sed "s/\b$arg\b/${arg}_renamed/g" "$in" > "$out" ;;
        *)     sed "$arg" "$in" > "$out" ;;
    esac
    if cmp -s "$in" "$out"; then
        FAIL=$((FAIL+1))
        report "[FAIL] mutation <$kind> did not change <$in>" 1
        return 1
    fi
}

# every error class has to end with exit 1, with -m (SPICE) and -k (CDL); w, l and m must
# show up as property errors under a matching topology. KLayout runs only <kinds for -k>
# (4 to 11 s per run). Set before: D, CELL, W, SPICE, CDL, PORT, SED_SPICE, SED_CDL
declare -A SED_SPICE SED_CDL
declare -A KIND_TEXT=(
    [w]="NMOS width doubled" [l]="NMOS length doubled" [m]="NMOS multiplier 2" [model]="NMOS of another model"
    [swap]="drain and gate swapped" [short]="gate tied to source" [del]="PMOS missing" [port]="port renamed"
)
lvs_error_classes() {
    local label=$1
    local kinds_k=${2:-w l m model swap short del port}
    local kind eng src ext arg net rep
    mkdir -p "$W/classes"
    for kind in w l m model swap short del port; do
        for eng in m k; do
            if [ "$eng" = k ] && ! echo " $kinds_k " | grep -q " $kind "; then
                continue
            fi
            if [ "$eng" = m ]; then
                src=$SPICE; ext=spice; arg=${SED_SPICE[$kind]}
            else
                src=$CDL; ext=cdl; arg=${SED_CDL[$kind]}
            fi
            [ "$kind" = port ] && arg=$PORT
            net=$W/classes/$kind.$ext
            mutate "$kind" "$src" "$net" "$arg" || continue
            check "$label: -$eng ${KIND_TEXT[$kind]}" 1 "$SAK" "-$eng" -s "$net" -l "$D/$CELL.gds" -c "$CELL" -w "$W/classes"
            if [ "$eng" = m ]; then
                rep=$W/classes/$CELL.magic.lvs/$CELL.lvs.out
                case $kind in
                    w|l|m) check "$label: ${KIND_TEXT[$kind]} is a property error" 0 bash -c "grep -q '^Final result: Circuits match uniquely\\.\$' '$rep' && grep -q '^Property errors were found\\.' '$rep'" ;;
                esac
            fi
        done
    done
}

# xschem schematic inv.sch with -b (both engines), then with the NMOS width doubled by <widen>
lvs_schematic() {
    local label=$1
    local widen=$2
    local ws=$W/sch
    mkdir -p "$ws/wide"
    check "$label: -b xschem schematic + GDS"         0 "$SAK" -b -s "$D/inv.sch" -l "$D/inv.gds" -c inv -w "$ws"
    check "$label: -b wrote the reports of both engines" 0 bash -c "[ -f '$ws/inv.magic.lvs/inv.lvs.out' ] && find '$ws/inv.klayout.lvs' -name '*.lvsdb' | grep -q ."
    mutate w "$D/inv.sch" "$ws/wide/inv.sch" "$widen" || return
    check "$label: -m schematic with NMOS width doubled" 1 "$SAK" -m -s "$ws/wide/inv.sch" -l "$D/inv.gds" -c inv -w "$ws/wide"
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

# every class of error, with both engines
SPICE=$D/$CELL.spice
CDL=$D/$CELL.cdl
PORT=Y
SED_SPICE=([w]='s/w=740.00n/w=1.48u/' [l]='0,/l=130.00n/s//l=260.00n/' [m]='0,/ m=1/s// m=2/' [model]='0,/sg13_lv_nmos/s//sg13_hv_nmos/')
SED_CDL=([w]='s/w=740.00n/w=1.48u/' [l]='0,/l=130.00n/s//l=260.00n/' [m]='0,/ m=1/s// m=2/' [model]='0,/sg13_lv_nmos/s//sg13_hv_nmos/')
lvs_error_classes "ihp"

# mm_ok=1 as written by the IHP xschem symbols must not cause a property error
mutate mm_ok "$SPICE" "$W/classes/mm_ok.spice" '/^X/s/$/ mm_ok=1/' &&
    check "ihp: -m SPICE with mm_ok=1"     0 "$SAK" -m -s "$W/classes/mm_ok.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W/classes"

# xschem schematic, both engines
lvs_schematic "ihp" 's/^w=0.74u$/w=1.48u/'

# Verilog netlist against a hierarchical layout of two inverters, then with the second one rewired
W6=$WORKDIR/ihp_hier
mkdir -p "$W6/rewired"
check "ihp: -m Verilog + hierarchical GDS"  0 "$SAK" -m -s "$D/invchain.v" -l "$D/invchain.gds" -c invchain -w "$W6"
mutate rewire "$D/invchain.v" "$W6/rewired/invchain.v" 's/\.A(n1)/.A(A)/' &&
    check "ihp: -m Verilog with an instance rewired" 1 "$SAK" -m -s "$W6/rewired/invchain.v" -l "$D/invchain.gds" -c invchain -w "$W6/rewired"
# the same hierarchical layout against netlists on transistor level
check "ihp: -m SPICE + hierarchical GDS"    0 "$SAK" -m -s "$D/invchain.spice" -l "$D/invchain.gds" -c invchain -w "$W6"
check "ihp: -k CDL + hierarchical GDS"      0 "$SAK" -k -s "$D/invchain.cdl"   -l "$D/invchain.gds" -c invchain -w "$W6"

# verdict: a stand-in for netgen writes a given report, for results an inverter cannot provoke
W7=$WORKDIR/ihp_verdict
mkdir -p "$W7/bin"
cat > "$W7/bin/netgen" <<'EOF'
#!/bin/sh
# stand-in for netgen: writes $NETGEN_REPORT into the report file, which is the last argument
for arg in "$@"; do report=$arg; done
printf '%s\n' "$NETGEN_REPORT" > "$report"
EOF
chmod +x "$W7/bin/netgen"
verdict() {
    local name=$1
    local expect=$2
    local text=$3
    check "verdict: $name" "$expect" env PATH="$W7/bin:$PATH" NETGEN_REPORT="$text" \
        "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W7"
}
verdict "match"                            0 $'Final result: Circuits match uniquely.\n.'
verdict "match with port errors"           1 'Final result: Circuits match uniquely with port errors.'
verdict "no match"                         1 'Final result: Netlists do not match.'
verdict "failed pin matching"              1 'Final result: Top level cell failed pin matching.'
verdict "property errors in the top cell"  1 $'Final result: Circuits match uniquely.\nProperty errors were found.'
verdict "property errors in a subcell"     1 $'Final result: Circuits match uniquely.\n.\n\nThe following cells had property errors:\n sg13_lv_nmos'
verdict "report without a final result"    1 $'Subcircuit summary:\nNetlists match uniquely.'

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

# a run that produces no result has to end with exit 5, not with a verdict
mkdir -p "$W/abort"
echo "this is not a GDS file" > "$W/abort/$CELL.gds"
printf '.subckt other_cell A B\n.ends\n' > "$W/abort/other.spice"
printf '.SUBCKT other_cell A B\n.ENDS\n' > "$W/abort/other.cdl"
check "abort: -k unreadable GDS"               5 "$SAK" -k -s "$D/$CELL.cdl"       -l "$W/abort/$CELL.gds" -c "$CELL" -w "$W/abort"
check "abort: -m netlist without the top cell" 5 "$SAK" -m -s "$W/abort/other.spice" -l "$D/$CELL.gds"     -c "$CELL" -w "$W/abort"
check "abort: -k netlist without the top cell" 5 "$SAK" -k -s "$W/abort/other.cdl"   -l "$D/$CELL.gds"     -c "$CELL" -w "$W/abort"

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

# same netlist notation as ihp-sg13g2, SED_SPICE and SED_CDL are reused
SPICE=$D/$CELL.spice
CDL=$D/$CELL.cdl
PORT=Y
lvs_error_classes "cmos5l" "w port"
mutate mm_ok "$SPICE" "$W/classes/mm_ok.spice" '/^X/s/$/ mm_ok=1/' &&
    check "cmos5l: -m SPICE with mm_ok=1"  0 "$SAK" -m -s "$W/classes/mm_ok.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W/classes"
lvs_schematic "cmos5l" 's/^w=0.74u$/w=1.48u/'

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

# -k without the port case: sak-lvs.sh runs the gf180mcu deck with check_ports=false
SPICE=$D/$CELL.spice
CDL=$D/$CELL.cdl
PORT=ZN
SED_SPICE=([w]='s/W=8.2e-07/W=1.64e-06/' [l]='s/L=6e-07/L=1.2e-06/' [m]='/nfet/s/$/ m=2/' [model]='s/nfet_05v0/nfet_03v3/')
SED_CDL=([w]='s/W=8.2e-07/W=1.64e-06/' [l]='s/L=6e-07/L=1.2e-06/' [m]='/nfet/s/$/ m=2/' [model]='s/nfet_05v0/nfet_03v3/')
lvs_error_classes "gf180" "w"
lvs_schematic "gf180" 's/^W=0.82u$/W=1.64u/'

# ============================================================================
# sky130A
# note: the Magic+Netgen run for a .sch schematic and a .mag layout is covered by test 02
# ============================================================================

# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > /dev/null 2>&1

D=$DIR/sky130A
CELL=sky130_fd_sc_hd__inv_1
W=$WORKDIR/sky130
mkdir -p "$W"

check "sky130: -m SPICE + GDS"             0 "$SAK" -m -s "$D/$CELL.spice" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# netlist as xschem writes it (subcircuit calls, W and L in micrometers), also the base of the -k error classes
check "sky130: -k xschem-style CDL + GDS"  0 "$SAK" -k -s "$D/${CELL}_xschem.cdl" -l "$D/$CELL.gds" -c "$CELL" -w "$W"

# -k without the port case: the sky130 deck does not compare port names
SPICE=$D/$CELL.spice
CDL=$D/${CELL}_xschem.cdl
PORT=Y
SED_SPICE=([w]='s/w=650000u/w=1.3e+06u/' [l]='0,/l=150000u/s//l=300000u/' [m]='/nfet/s/$/ m=2/' [model]='s/nfet_01v8 /nfet_01v8_lvt /')
SED_CDL=([w]='s/W=0.65/W=1.3/' [l]='0,/L=0.15/s//L=0.3/' [m]='0,/m=1/s//m=2/' [model]='s/nfet_01v8 /nfet_01v8_lvt /')
lvs_error_classes "sky130" "w"
lvs_schematic "sky130" 's/^W=0.65$/W=1.3/'

# ============================================================================
# summary
# ============================================================================

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <sak-lvs.sh regression> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <sak-lvs.sh regression> passed ($PASS checks)."
    exit 0
fi
