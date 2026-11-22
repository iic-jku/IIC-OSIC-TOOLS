#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# SAK commands with asap7, on the standard cell INVx1_ASAP7_75t_R:
# * sak-drc.sh --json without an engine flag runs KLayout DRC (asap7 has no
#   Magic technology) and reports only the latch-up tap rule ACTIVE.LUP.1
# * sak-lvs.sh --json matches the layout to its CDL and fails against a CDL
#   with a wrong fin count
# * sak-gds-info.py and sak-render.py know the asap7 layers

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="SAK DRC, LVS, GDS info and render with asap7"
WORKDIR=${RUNS_DIR}/${RAND}/64
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
REF="$PDK_ROOT/asap7/libs.ref/asap7sc7p5t"
CELL=INVx1_ASAP7_75t_R
FAILED=""

# The cell as its own GDS and CDL, the names sak-drc.sh and sak-lvs.sh resolve
python3 - "$REF/gds/asap7sc7p5t_28_R_220121a.gds" "$CELL" <<'PY'
import sys
import klayout.db as db
layout = db.Layout()
layout.read(sys.argv[1])
cell = layout.cell(sys.argv[2])
keep = {cell.cell_index()} | set(cell.called_cells())
for index in [c.cell_index() for c in layout.each_cell()]:
    if index not in keep:
        layout.delete_cell(index)
layout.write(sys.argv[2] + ".gds")
PY
awk "/^\\.SUBCKT $CELL /,/^\\.ENDS/" "$REF/cdl/asap7sc7p5t_28_R.cdl" > "$CELL.cdl"
[ -s "$CELL.gds" ] && [ -s "$CELL.cdl" ] || FAILED="could not extract $CELL"

json_get() {
    python3 -c "import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))" "$1" "$2" 2> /dev/null
}

if [ -z "$FAILED" ]; then
    sak-drc.sh --json "$CELL" > drc.json 2> drc.log
    RULES=$(json_get drc.json "' '.join(sorted({r['rule'] for rep in d['reports'] for r in rep['rules']}))")
    ENGINE=$(json_get drc.json "d['reports'][0]['engine']")
    [ "$ENGINE" = "klayout" ] || FAILED="sak-drc.sh did not run KLayout DRC (engine <$ENGINE>)"
    [ -z "$FAILED" ] && [ "$RULES" != "ACTIVE.LUP.1" ] && FAILED="sak-drc.sh reports <$RULES> instead of ACTIVE.LUP.1 only"
fi

if [ -z "$FAILED" ]; then
    sak-lvs.sh --json "$CELL" > lvs.json 2> lvs.log
    [ "$(json_get lvs.json "d['match']")" = "True" ] || FAILED="sak-lvs.sh does not match $CELL to its CDL"
fi
if [ -z "$FAILED" ]; then
    mkdir -p wrong && sed 's/nmos_rvt w=81.0n l=20n nfin=3/nmos_rvt w=81.0n l=20n nfin=4/' "$CELL.cdl" > "wrong/$CELL.cdl"
    sak-lvs.sh --json -k -w "$WORKDIR/wrong" -s "wrong/$CELL.cdl" -l "$CELL.gds" -c "$CELL" > wrong/lvs.json 2> wrong/lvs.log
    [ "$(json_get wrong/lvs.json "d['match']")" = "False" ] || FAILED="sak-lvs.sh matches $CELL against a CDL with nfin=4"
fi

if [ -z "$FAILED" ]; then
    sak-gds-info.py --json -t asap7 "$CELL.gds" > info.json 2> info.log
    M1=$(json_get info.json "[l['name'] for l in d['layers'] if (l['layer'], l['datatype']) == (19, 0)][0]")
    [ "$M1" = "M1" ] || FAILED="sak-gds-info.py names layer 19/0 <$M1> instead of M1"
fi
if [ -z "$FAILED" ]; then
    sak-render.py -t asap7 -b white "$CELL.gds" -o inv.png > render.log 2>&1
    [ -s inv.png ] || FAILED="sak-render.py wrote no image"
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
