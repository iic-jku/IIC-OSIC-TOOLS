#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-render.py keeps its default output, and if --bbox renders a region and --json reports
# the rendered files, the region and the scale as one JSON object, also on errors.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/57
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > pdk.log 2>&1

# top: a 10 by 5 box on 10/0 (Metal2) and a 2 by 3 array of sub (1x1 box on 8/0, Metal1)
python3 - <<'PYEOF' || ERROR=1
import pya

ly = pya.Layout()
ly.dbu = 0.001
sub = ly.create_cell("sub")
sub.shapes(ly.layer(8, 0)).insert(pya.DBox(0, 0, 1.0, 1.0))
top = ly.create_cell("top")
top.insert(pya.CellInstArray(sub.cell_index(), pya.Trans(), pya.Vector(2000, 0), pya.Vector(0, 2000), 3, 2))
top.shapes(ly.layer(10, 0)).insert(pya.DBox(0, 0, 10.0, 5.0))
ly.write("top.gds")
PYEOF

# png_size <file>: width and height from the PNG header
png_size() {
    python3 -c "import struct,sys; h=open(sys.argv[1],'rb').read(24); assert h[:8]==b'\x89PNG\r\n\x1a\n'; print(*struct.unpack('>II', h[16:24]))" "$1"
}

# check <name> <expected exit> <python assertion on d> <sak-render.py args...>
check() {
    local name=$1 want=$2 assertion=$3
    shift 3
    local out rc
    out=$(sak-render.py "$@" 2> "$WORKDIR/stderr.txt")
    rc=$?
    if [ $rc -ne "$want" ]; then
        echo "[ERROR] $name: exit code $rc, expected $want"
        [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/stderr.txt"; }
        ERROR=1
        return
    fi
    if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert $assertion" 2> "$WORKDIR/assert.txt"; then
        echo "[ERROR] $name: field check failed: $assertion"
        [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/assert.txt"; }
        ERROR=1
    fi
}

# without the new options: both images, [INFO] lines on stdout, no JSON
OUT=$(sak-render.py -o "$WORKDIR/a.png" "$WORKDIR/top.gds" 2> "$WORKDIR/stderr.txt")
RC=$?
if [ $RC -ne 0 ] || [ ! -s "$WORKDIR/a_white.png" ] || [ ! -s "$WORKDIR/a_black.png" ] \
    || ! printf '%s' "$OUT" | grep -q '^\[INFO\] Written ' \
    || printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null; then
    echo "[ERROR] default output is wrong (exit code $RC)"
    [ -n "$DEBUG" ] && { echo "$OUT"; cat "$WORKDIR/stderr.txt"; }
    ERROR=1
fi

check "json full extent" 0 "d['status']=='ok' and d['schema']==1 and d['tool']=='sak-render' and d['input'][0]['path']=='$WORKDIR/top.gds' and d['bbox_um']==[0.0,0.0,10.0,5.0] and d['um_per_px']==0.01 and d['files']==[{'path':'$WORKDIR/b.png','background':'white','width_px':1000,'height_px':500}]" \
    --json -b white -o "$WORKDIR/b.png" -w 1000 "$WORKDIR/top.gds"
if [ "$(png_size "$WORKDIR/b.png")" != "1000 500" ]; then
    echo "[ERROR] b.png has size $(png_size "$WORKDIR/b.png"), expected 1000 500"
    ERROR=1
fi

check "json bbox region" 0 "d['bbox_um']==[0.0,0.0,5.0,5.0] and d['um_per_px']==0.01 and d['files'][0]['width_px']==500 and d['files'][0]['height_px']==500" \
    --json -b white -o "$WORKDIR/c.png" -w 500 --bbox 0,0,5,5 "$WORKDIR/top.gds"
if [ "$(png_size "$WORKDIR/c.png")" != "500 500" ]; then
    echo "[ERROR] c.png has size $(png_size "$WORKDIR/c.png"), expected 500 500"
    ERROR=1
fi

check "json both backgrounds" 0 "[f['background'] for f in d['files']]==['white','black']" \
    --json -o "$WORKDIR/e.png" -w 200 "$WORKDIR/top.gds"
check "negative bbox" 0 "d['bbox_um']==[-1.0,-1.0,2.0,2.0] and d['files'][0]['height_px']==300" \
    --json -b white -o "$WORKDIR/f.png" -w 300 --bbox=-1,-1,2,2 "$WORKDIR/top.gds"
check "bbox outside" 1 "d['status']=='error' and 'error' in d" --json --bbox 100,100,110,110 -o "$WORKDIR/g.png" "$WORKDIR/top.gds"
check "bbox three values" 1 "d['status']=='error'" --json --bbox 1,2,3 -o "$WORKDIR/g.png" "$WORKDIR/top.gds"
check "bbox empty" 1 "d['status']=='error'" --json --bbox 3,3,1,1 -o "$WORKDIR/g.png" "$WORKDIR/top.gds"
check "missing file" 1 "d['status']=='error'" --json "$WORKDIR/missing.gds"
check "usage error" 2 "d['status']=='error'" --json --nosuchoption "$WORKDIR/top.gds"

# the error without --json stays a text message with exit code 1
OUT=$(sak-render.py --bbox 100,100,110,110 -o "$WORKDIR/g.png" "$WORKDIR/top.gds" 2> /dev/null)
RC=$?
if [ $RC -ne 1 ] || [ -e "$WORKDIR/g_white.png" ]; then
    echo "[ERROR] bbox outside without --json: exit code $RC, expected 1 and no image"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <sak-render bbox and json> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-render bbox and json> passed."
    exit 0
fi
