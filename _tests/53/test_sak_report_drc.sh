#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-report.py summarizes KLayout (lyrdb) and Magic DRC reports as JSON and text,
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
sleep 1
touch newer.marker

# check <name> <expected exit> <python assertion on d> <args...>
check() {
    local name=$1 want=$2 assertion=$3
    shift 3
    local out rc
    out=$(sak-report.py "$@" 2> "$WORKDIR/stderr.txt")
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

check "two.lyrdb" 1 "d['status']=='findings' and d['total']==4 and d['schema']==1 and d['input'][0]['path'].endswith('two.lyrdb') and r['rules'][0]['rule']=='M1.b' and r['rules'][0]['count']==3 and r['rules'][0]['markers'][0]['bbox_um']==[0.0,0.0,0.05,1.0] and r['rules'][0]['description']=='Min. Metal1 space'" --json two.lyrdb
check "clean.lyrdb" 0 "d['status']=='clean' and d['total']==0" --json clean.lyrdb
check "big.lyrdb" 1 "r['rules'][0]['count']==5000 and len(r['rules'][0]['markers'])==20 and d['cap']==20" --json big.lyrdb
check "big.lyrdb --max 0" 1 "len(r['rules'][0]['markers'])==5000" --json --max 0 big.lyrdb
check "cut.lyrdb" 2 "d['status']=='error'" --json cut.lyrdb
check "missing.lyrdb" 2 "d['status']=='error'" --json missing.lyrdb
check "two.magic" 1 "r['format']=='magic' and d['total']==2" --json two.magic.drc.rpt
check "clean.magic" 0 "d['total']==0" --json clean.magic.drc.rpt
check "crashed.magic" 2 "d['status']=='error'" --json crashed.magic.drc.rpt
check "two reports" 1 "d['total']==6 and len(d['reports'])==2" --json two.lyrdb two.magic.drc.rpt
check "stale report" 2 "'older than' in d['error']" --json --newer-than newer.marker two.lyrdb
check "no report" 3 "" --json

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
