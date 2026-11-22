#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-report.py summarizes the KLayout (lvsdb) and Netgen LVS reports of a matching and
# of a mismatching sky130A inverter as JSON, and rejects truncated reports and mixed DRC/LVS calls.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/55
mkdir -p "$WORKDIR/lay" "$WORKDIR/ok" "$WORKDIR/bad"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh sky130A > pdk.log 2>&1

# KLayout LVS needs a GDS layout, so write one from the Magic layout (the test directory is read-only)
cp "$DIR"/../02/*.mag lay/
printf 'load inv\ngds write inv.gds\nquit -noprompt\n' > lay/gds.tcl
(cd lay && magic -dnull -noconsole -rcfile "$PDK_ROOT/$PDK/libs.tech/magic/${PDK}.magicrc" gds.tcl > gds.log 2>&1)
if [ ! -s lay/inv.gds ]; then
    echo "[ERROR] Magic did not write the GDS of the inverter"
    [ -n "$DEBUG" ] && cat lay/gds.log
    echo "[ERROR] Test <sak-report LVS summary> FAILED."
    exit 1
fi

# matching run, both engines
sak-lvs.sh -b -w "$WORKDIR/ok" -s "$DIR/../02/inv.sch" -l "$WORKDIR/lay/inv.gds" -c inv > ok.log 2>&1 || {
    echo "[ERROR] LVS of the unmodified inverter failed"
    [ -n "$DEBUG" ] && cat ok.log
    ERROR=1
}

# mismatching run: tie the gate of the PMOS to VDD in the netlists written by the first run
# (a source/drain swap would still match, both engines treat the two as equivalent)
sed '/^XM10/s/^XM10 out in VDD VDD/XM10 out VDD VDD VDD/' ok/inv_magic.spice > bad/bad_magic.spice
sed '/^XM10/s/^XM10 out in VDD VDD/XM10 out VDD VDD VDD/' ok/inv_klayout.cdl > bad/bad_klayout.cdl
sak-lvs.sh -m -w "$WORKDIR/bad" -s "$WORKDIR/bad/bad_magic.spice" -l "$WORKDIR/lay/inv.gds" -c inv > bad_m.log 2>&1
[ $? -eq 1 ] || { echo "[ERROR] Magic+Netgen LVS of the planted mismatch did not exit with 1"; ERROR=1; }
sak-lvs.sh -k -w "$WORKDIR/bad" -s "$WORKDIR/bad/bad_klayout.cdl" -l "$WORKDIR/lay/inv.gds" -c inv > bad_k.log 2>&1
[ $? -eq 1 ] || { echo "[ERROR] KLayout LVS of the planted mismatch did not exit with 1"; ERROR=1; }

OK_DB=$(find ok -name '*.lvsdb' | head -n 1)
OK_OUT=$(find ok -name '*.lvs.out' | head -n 1)
BAD_DB=$(find bad -name '*.lvsdb' | head -n 1)
BAD_OUT=$(find bad -name '*.lvs.out' | head -n 1)
if [ -z "$OK_DB" ] || [ -z "$OK_OUT" ] || [ -z "$BAD_DB" ] || [ -z "$BAD_OUT" ]; then
    echo "[ERROR] LVS reports not found (lvsdb ok: '$OK_DB', netgen ok: '$OK_OUT', lvsdb bad: '$BAD_DB', netgen bad: '$BAD_OUT')"
    echo "[ERROR] Test <sak-report LVS summary> FAILED."
    exit 1
fi

head -c 200 "$OK_OUT" > cut.lvs.out
python3 - <<'PYEOF' || ERROR=1
import pya
rdb = pya.ReportDatabase("test")
cell = rdb.create_cell("top")
cat = rdb.create_category("M1.b")
item = rdb.create_item(cell.rdb_id(), cat.rdb_id())
item.add_value(pya.DBox(0, 0, 0.05, 1.0))
rdb.save("one.lyrdb")
PYEOF

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

check "ok lvsdb" 0 "d['status']=='clean' and d['kind']=='lvs' and d['match'] is True and r['format']=='lvsdb' and r['engine']=='klayout' and r['match'] is True and r['layout']['devices']==2 and r['schematic']['devices']==2 and r['layout']['nets']==4 and r['unmatched_available'] is True and r['unmatched']['nets']==[]" --json "$OK_DB"
check "ok netgen" 0 "d['match'] is True and r['format']=='netgen' and r['engine']=='netgen' and r['layout']['devices']==2 and r['schematic']['nets']==4 and r['property_errors'] is False and r['unmatched_available'] is False" --json "$OK_OUT"
check "bad lvsdb" 1 "d['status']=='findings' and d['match'] is False and r['match'] is False and r['unmatched_available'] is True and len(r['unmatched']['nets'])>0 and r['unmatched_count']['nets']>0" --json "$BAD_DB"
check "bad netgen" 1 "d['match'] is False and r['match'] is False" --json "$BAD_OUT"
check "ok lvsdb + bad netgen" 1 "d['match'] is False and len(d['reports'])==2" --json "$OK_DB" "$BAD_OUT"
check "lvsdb + drc" 3 "d['status']=='error'" --json "$OK_DB" one.lyrdb
check "drc + lvsdb" 3 "d['status']=='error'" --json one.lyrdb "$OK_DB"
check "ok lvsdb + cut netgen" 2 "d['status']=='error'" --json "$OK_DB" cut.lvs.out
check "cut netgen" 2 "d['status']=='error'" --json cut.lvs.out

# without --json: text with the verdict
TXT=$(sak-report.py "$BAD_DB" 2> /dev/null)
RC=$?
if [ $RC -ne 1 ] || printf '%s' "$TXT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null \
    || ! printf '%s' "$TXT" | grep -q 'MISMATCH'; then
    echo "[ERROR] text output of the mismatching lvsdb is wrong (exit code $RC)"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <sak-report LVS summary> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-report LVS summary> passed."
    exit 0
fi
