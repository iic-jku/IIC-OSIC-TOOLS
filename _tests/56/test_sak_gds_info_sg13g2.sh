#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-gds-info.py reports layers, bounding box, cell tree and labels of a layout as JSON,
# counts array placements, honors --bbox, -c and -t, and rejects missing files and ambiguous top cells.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/56
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > pdk.log 2>&1

# top: 2 by 3 array of sub (one 1x1 box on 8/0, pitch 2.0), a box on 10/0 and the label VDD on 8/25
python3 - <<'PYEOF' || ERROR=1
import pya

ly = pya.Layout()
ly.dbu = 0.001
sub = ly.create_cell("sub")
sub.shapes(ly.layer(8, 0)).insert(pya.DBox(0, 0, 1.0, 1.0))
top = ly.create_cell("top")
top.insert(pya.CellInstArray(sub.cell_index(), pya.Trans(), pya.Vector(2000, 0), pya.Vector(0, 2000), 3, 2))
top.shapes(ly.layer(10, 0)).insert(pya.DBox(0, 0, 10.0, 5.0))
top.shapes(ly.layer(8, 25)).insert(pya.DText("VDD", 1.0, 1.0))
ly.write("top.gds")

ly = pya.Layout()
ly.dbu = 0.001
for name in ("a", "b"):
    ly.create_cell(name).shapes(ly.layer(8, 0)).insert(pya.DBox(0, 0, 1.0, 1.0))
ly.write("two_tops.gds")
PYEOF
gzip -c top.gds > top.gds.gz

# check <name> <expected exit> <python assertion on d> <sak-gds-info.py args...>
check() {
    local name=$1 want=$2 assertion=$3
    shift 3
    local out rc
    out=$(sak-gds-info.py "$@" 2> "$WORKDIR/stderr.txt")
    rc=$?
    if [ $rc -ne "$want" ]; then
        echo "[ERROR] $name: exit code $rc, expected $want"
        [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/stderr.txt"; }
        ERROR=1
        return
    fi
    if [ -n "$assertion" ]; then
        if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); L={(l['layer'],l['datatype']):l for l in d.get('layers',[])}; assert $assertion" 2> "$WORKDIR/assert.txt"; then
            echo "[ERROR] $name: field check failed: $assertion"
            [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/assert.txt"; }
            ERROR=1
        fi
    fi
}

check "all parts" 0 "d['status']=='ok' and d['schema']==1 and d['tool']=='sak-gds-info' and d['input'][0]['path']=='top.gds' and d['cell']=='top' and d['top_cells']==['top'] and d['dbu']==0.001 and d['bbox_um']==[0.0,0.0,10.0,5.0] and L[(8,0)]['shapes']==6 and L[(8,0)]['name'].startswith('Metal1') and L[(8,0)]['bbox_um']==[0.0,0.0,5.0,3.0] and L[(10,0)]['shapes']==1 and d['cells']['name']=='top' and d['cells']['children'][0]=={'name':'sub','instances':6,'children':[]} and d['labels'][0]['text']=='VDD' and d['labels'][0]['layer']==8 and d['labels'][0]['datatype']==25 and d['labels'][0]['x_um']==1.0 and d['labels_total']==1 and d['cap']==20" --json top.gds
check "layers only" 0 "'layers' in d and 'cells' not in d and 'labels' not in d" --json --layers top.gds
check "cells only" 0 "'cells' in d and 'layers' not in d and 'labels' not in d" --json --cells top.gds
check "labels only" 0 "'labels' in d and 'layers' not in d and 'cells' not in d" --json --labels top.gds
check "bbox region" 0 "L[(8,0)]['shapes']==1" --json --bbox 0,0,1.5,1.5 top.gds
check "unknown pdk" 0 "len(L)>0 and all(l['name'] is None for l in L.values())" --json -t nosuchpdk top.gds
check "two top cells" 3 "d['status']=='error' and d['top_cells']==['a','b']" --json two_tops.gds
check "select cell" 0 "d['cell']=='b'" --json -c b two_tops.gds
check "unknown cell" 3 "d['status']=='error'" --json -c nope top.gds
check "missing file" 2 "d['status']=='error'" --json missing.gds
check "gzip input" 0 "d['bbox_um']==[0.0,0.0,10.0,5.0] and L[(8,0)]['shapes']==6" --json top.gds.gz
check "depth 0" 0 "d['cells']['children']==[]" --json --depth 0 top.gds
check "max 0" 0 "d['cap']==0" --json --max 0 top.gds

# without --json: text, no JSON
TXT=$(sak-gds-info.py top.gds 2> /dev/null)
RC=$?
if [ $RC -ne 0 ] || printf '%s' "$TXT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null \
    || ! printf '%s' "$TXT" | grep -q 'VDD' || ! printf '%s' "$TXT" | grep -q 'sub'; then
    echo "[ERROR] text output of top.gds is wrong (exit code $RC)"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <sak-gds-info layout facts> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-gds-info layout facts> passed."
    exit 0
fi
