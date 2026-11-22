#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if DRC and LVS are OK on a simple inverter in sky130A, also with --json.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT=${RUNS_DIR}/${RAND}/02/result_layver_sky130a.log
WORKDIR=${RUNS_DIR}/${RAND}/02

mkdir -p "$WORKDIR"

# Switch to sky130A PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > "$RESULT" 2>&1
# Run the DRC
sak-drc.sh -w "$WORKDIR" -b "$DIR/inv.mag"  > "$RESULT" 2>&1 || ERROR=1
# without --json the messages stay on stdout
grep -q '^\[INFO\]' "$RESULT" || { echo "[ERROR] sak-drc.sh printed no [INFO] line on stdout"; ERROR=1; }
# Run the LVS
sak-lvs.sh -w "$WORKDIR" -s "$DIR/inv.sch" -l "$DIR/inv.mag" -c inv  >> "$RESULT" 2>&1 || ERROR=1

# jcheck <name> <expected exit> <python assertion on d> <command...>: stdout of the command must be one JSON object
jcheck() {
    local name=$1 want=$2 assertion=$3
    shift 3
    local out rc
    out=$("$@" 2> "$WORKDIR/jcheck_stderr.txt")
    rc=$?
    if [ $rc -ne "$want" ]; then
        echo "[ERROR] $name: exit code $rc, expected $want"
        ERROR=1
        return
    fi
    if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert $assertion" 2> "$WORKDIR/jcheck_assert.txt"; then
        echo "[ERROR] $name: field check failed: $assertion"
        [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/jcheck_assert.txt"; }
        ERROR=1
    fi
}

# KLayout needs a GDS, with the .mag layout -b would run Magic only. Write a GDS of the inverter (the test directory is read-only).
mkdir -p "$WORKDIR/gds"
cp "$DIR"/*.mag "$WORKDIR/gds/"
printf 'load inv\ngds write inv.gds\nquit -noprompt\n' > "$WORKDIR/gds/gds.tcl"
(cd "$WORKDIR/gds" && magic -dnull -noconsole -rcfile "$PDK_ROOT/$PDK/libs.tech/magic/${PDK}.magicrc" gds.tcl > gds.log 2>&1)
[ -s "$WORKDIR/gds/inv.gds" ] || { echo "[ERROR] Magic did not write the GDS of the inverter"; ERROR=1; }

jcheck "drc --json clean" 0 "d['status']=='clean' and d['tool']=='sak-drc' and len(d['reports'])>=2 and {r['engine'] for r in d['reports']} >= {'magic','klayout'}" \
    sak-drc.sh --json -w "$WORKDIR/gds" -b "$WORKDIR/gds/inv.gds"

# two met1 rectangles 0.05 um apart violate the met1 spacing rule in both engines
python3 - "$WORKDIR/viol.gds" <<'PYEOF' || ERROR=1
import sys
import pya
ly = pya.Layout()
ly.dbu = 0.001
top = ly.create_cell("viol")
met1 = ly.layer(68, 20)
top.shapes(met1).insert(pya.DBox(0, 0, 1, 1))
top.shapes(met1).insert(pya.DBox(1.05, 0, 2.05, 1))
ly.write(sys.argv[1])
PYEOF
jcheck "drc --json violations" 1 "d['status']=='findings' and d['total']>=2 and {r['format'] for r in d['reports']} >= {'magic','lyrdb'}" \
    sak-drc.sh --json -w "$WORKDIR/viol" -b "$WORKDIR/viol.gds"
jcheck "lvs --json" 0 "d['match'] is True and d['tool']=='sak-lvs' and d['reports'][0]['engine']=='netgen'" \
    sak-lvs.sh --json -w "$WORKDIR" -s "$DIR/inv.sch" -l "$DIR/inv.mag" -c inv
jcheck "drc --json missing layout" 2 "d['status']=='error' and d['exit_code']==2 and d['tool']=='sak-drc'" \
    sak-drc.sh --json -w "$WORKDIR" "$WORKDIR/nonexistent.gds"
# Check if there is an error in the log
if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <LayVer of sky130 inv> FAILED."
    exit 1
else
    echo "[INFO] Test <LayVer of sky130 inv> passed."
    exit 0
fi
