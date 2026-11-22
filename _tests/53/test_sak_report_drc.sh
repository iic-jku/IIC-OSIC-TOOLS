#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-report.py summarizes KLayout (lyrdb), gdscheck (lyrdb) and Magic DRC reports as JSON and text,
# and treats missing, truncated, crashed and stale reports as input errors.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/53
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > pdk.log 2>&1

# Build the input reports
python3 - <<'PYEOF' || ERROR=1
import pya

def make(path, cats):
    rdb = pya.ReportDatabase("test")
    cell = rdb.create_cell("top")
    for name, desc, n in cats:
        cat = rdb.create_category(name)
        cat.description = desc
        for i in range(n):
            item = rdb.create_item(cell.rdb_id(), cat.rdb_id())
            item.add_value(pya.DBox(0 + i, 0, 0.05 + i, 1.0))
    rdb.save(path)

make("two.lyrdb", [("M1.b", "Min. Metal1 space", 3), ("M2.a", "Min. Metal2 width", 1)])
make("clean.lyrdb", [("M1.b", "Min. Metal1 space", 0)])
make("big.lyrdb", [("M1.b", "Min. Metal1 space", 5000)])

def make_waived(path, cats):
    # cats: (name, normal items, waived items), the waived tag is the one gdscheck writes
    rdb = pya.ReportDatabase("test")
    cell = rdb.create_cell("top")
    waived = rdb.tag_id("waived")
    for name, normal, waivedn in cats:
        cat = rdb.create_category(name)
        for i in range(normal + waivedn):
            item = rdb.create_item(cell.rdb_id(), cat.rdb_id())
            item.add_value(pya.DBox(0 + i, 0, 0.05 + i, 1.0))
            if i >= normal:
                item.add_tag(waived)
    rdb.save(path)

make_waived("waived.lyrdb", [("A", 2, 1), ("B", 0, 1)])
make_waived("waived_only.lyrdb", [("A", 0, 2)])
with open("two.lyrdb", "rb") as f:
    data = f.read(300)
with open("cut.lyrdb", "wb") as f:
    f.write(data)
PYEOF

D="----------------------------------------"
cat > two.magic.drc.rpt <<RPT
top
$D
Metal1 spacing < 0.18um (met1.2)
$D
 0.000um 0.000um 0.050um 1.000um
 1.000um 0.000um 1.050um 1.000um
$D
[INFO] COUNT: 2
[INFO] Should be divided by 3 or 4

RPT
cat > clean.magic.drc.rpt <<RPT
top
$D
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4

RPT
grep -v 'COUNT\|divided' two.magic.drc.rpt > crashed.magic.drc.rpt
# well-formed report database with an item without a category (loads, then fails in the reader)
cat > broken.lyrdb <<RPT
<?xml version="1.0" encoding="utf-8"?>
<report-database>
 <categories><category><name>A</name></category></categories>
 <cells><cell><name>top</name></cell></cells>
 <items>
  <item><cell>top</cell><values><value>box: (0,0;1,1)</value></values></item>
 </items>
</report-database>
RPT
sleep 1
touch newer.marker

# run_check <name> <expected exit> <python assertion on d> <command...>
run_check() {
    local name=$1 want=$2 assertion=$3
    shift 3
    local out rc
    out=$("$@" 2> "$WORKDIR/stderr.txt")
    rc=$?
    if [ $rc -ne "$want" ]; then
        echo "[ERROR] $name: exit code $rc, expected $want"
        ERROR=1
        return
    fi
    if [ -n "$assertion" ]; then
        if ! printf '%s' "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); r=d['reports'][0] if d.get('reports') else None; assert $assertion" 2> "$WORKDIR/assert.txt"; then
            echo "[ERROR] $name: field check failed: $assertion"
            [ -n "$DEBUG" ] && { echo "$out"; cat "$WORKDIR/assert.txt"; }
            ERROR=1
        fi
    fi
}

# check <name> <expected exit> <python assertion on d> <sak-report.py args...>
check() {
    local name=$1 want=$2 assertion=$3
    shift 3
    run_check "$name" "$want" "$assertion" sak-report.py "$@"
}

check "two.lyrdb" 1 "d['status']=='findings' and d['total']==4 and d['schema']==1 and d['input'][0]['path'].endswith('two.lyrdb') and r['engine']=='klayout' and r['rules'][0]['rule']=='M1.b' and r['rules'][0]['count']==3 and r['rules'][0]['markers'][0]['bbox_um']==[0.0,0.0,0.05,1.0] and r['rules'][0]['description']=='Min. Metal1 space'" --json two.lyrdb
check "clean.lyrdb" 0 "d['status']=='clean' and d['total']==0" --json clean.lyrdb
check "big.lyrdb" 1 "r['rules'][0]['count']==5000 and len(r['rules'][0]['markers'])==20 and d['cap']==20" --json big.lyrdb
check "big.lyrdb --max 0" 1 "len(r['rules'][0]['markers'])==5000" --json --max 0 big.lyrdb
check "cut.lyrdb" 2 "d['status']=='error'" --json cut.lyrdb
check "missing.lyrdb" 2 "d['status']=='error'" --json missing.lyrdb
check "two.magic" 1 "r['format']=='magic' and r['engine']=='magic' and d['total']==2" --json two.magic.drc.rpt
check "clean.magic" 0 "d['total']==0" --json clean.magic.drc.rpt
check "crashed.magic" 2 "d['status']=='error'" --json crashed.magic.drc.rpt
check "two reports" 1 "d['total']==6 and len(d['reports'])==2" --json two.lyrdb two.magic.drc.rpt
check "stale report" 2 "'older than' in d['error']" --json --newer-than newer.marker two.lyrdb
check "no report" 3 "d['status']=='error' and d['schema']==1" --json
check "unreadable content" 2 "d['status']=='error' and 'unexpected' in d['error']" --json broken.lyrdb

check "waived items" 1 "d['status']=='findings' and d['total']==2 and d['waived']==2 and r['total']==2 and r['waived']==2 and r['rules'][0]['rule']=='A' and r['rules'][0]['count']==2 and r['rules'][0]['waived']==1 and len(r['rules'][0]['markers'])==2 and r['rules'][1]['rule']=='B' and r['rules'][1]['count']==0 and r['rules'][1]['waived']==1 and r['rules'][1]['markers']==[]" --json waived.lyrdb
check "waived items only" 0 "d['status']=='clean' and d['total']==0 and d['waived']>0" --json waived_only.lyrdb
check "no waivers" 1 "d['waived']==0 and r['waived']==0 and r['rules'][0]['waived']==0" --json two.lyrdb
check "tool option" 0 "d['tool']=='sak-drc'" --json --tool sak-drc clean.lyrdb
check "tool option on error" 2 "d['tool']=='sak-drc' and d['status']=='error'" --json --tool sak-drc missing.lyrdb

# gdscheck is the third DRC engine of sak-drc.sh. Two Metal1 rectangles 0.05 um apart violate M1.b.
python3 - <<'PYEOF' || ERROR=1
import pya
ly = pya.Layout()
ly.dbu = 0.001
top = ly.create_cell("gviol")
m1 = ly.layer(8, 0)
top.shapes(m1).insert(pya.DBox(0, 0, 1, 1))
top.shapes(m1).insert(pya.DBox(1.05, 0, 2.05, 1))
ly.write("gviol.gds")
PYEOF
run_check "sak-drc.sh --json -g" 1 "d['status']=='findings' and d['tool']=='sak-drc' and len(d['reports'])==1 and r['engine']=='gdscheck' and r['format']=='lyrdb' and d['total']>=1 and any('M1' in x['rule'] for x in r['rules'])" \
    sak-drc.sh --json -g -w "$WORKDIR/g" "$WORKDIR/gviol.gds"
check "gdscheck lyrdb" 1 "r['engine']=='gdscheck' and d['total']>=1" --json "$WORKDIR/g/gviol.gdscheck.drc/gviol.lyrdb"

# without --json: text naming the rule and its count
TXT=$(sak-report.py two.lyrdb 2> /dev/null)
RC=$?
if [ $RC -ne 1 ] || printf '%s' "$TXT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null \
    || ! printf '%s' "$TXT" | grep -q 'M1\.b' || ! printf '%s' "$TXT" | grep -q '3'; then
    echo "[ERROR] text output of two.lyrdb is wrong (exit code $RC)"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <sak-report DRC summary> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-report DRC summary> passed."
    exit 0
fi
