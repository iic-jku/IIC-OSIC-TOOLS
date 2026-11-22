#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# KLayout LVS and DRC decks of ASAP7 on the RVT standard cells:
# * LVS of every RVT cell that has a CDL netlist. The cells that do not match
#   have to be exactly the ones in lvs_known_mismatch.txt, so a regression of
#   the deck and a fixed cell both show up.
# * LVS of INVx1 against a CDL with nfin=4 instead of 3 has to fail, so the
#   deck compares the fin count and does not pass everything.
# * The DRC deck (ASAP7_for_KLayout, adapted by fix_asap7_drc_deck.py) has to
#   write its report to -rd report=, and an isolated INVx1 violates only the
#   latch-up tap rule ACTIVE.LUP.1 (it has no tap of its own).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="KLayout LVS and DRC of the ASAP7 standard cells"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/61
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
REF="$PDK_ROOT/asap7/libs.ref/asap7sc7p5t"
GDS="$REF/gds/asap7sc7p5t_28_R_220121a.gds"
CDL="$REF/cdl/asap7sc7p5t_28_R.cdl"
LVS="$PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs"
DRC="$PDK_ROOT/asap7/libs.tech/klayout/drc/asap7.lydrc"
FAILED=""

# Every cell of the GDS that has a subcircuit in the CDL
python3 - "$GDS" "$CDL" > cells.txt <<'PY'
import sys
import klayout.db as db
layout = db.Layout()
layout.read(sys.argv[1])
cdl = {l.split()[1].upper() for l in open(sys.argv[2]) if l.upper().startswith(".SUBCKT")}
for c in layout.top_cells():
    if c.name.upper() in cdl:
        print(c.name)
PY
[ -s cells.txt ] || FAILED="no cells found in $GDS"

# shellcheck disable=SC2329 # called through xargs
lvs_cell() {
    klayout -b -r "$LVS" -rd threads=1 -rd input="$GDS" -rd topcell="$1" -rd schematic="$CDL" \
        -rd report="$PWD/$1.lvsdb" > "$1.lvs.log" 2>&1
    if grep -q "netlists match" "$1.lvs.log"; then echo "PASS $1"; else echo "FAIL $1"; fi
}
export -f lvs_cell
export GDS CDL LVS

if [ -z "$FAILED" ]; then
    # shellcheck disable=SC2016 # expanded by the inner bash
    xargs -P "$(nproc)" -n 1 bash -c 'lvs_cell "$0"' < cells.txt > lvs_results.txt
    N_CELLS=$(wc -l < cells.txt)
    N_PASS=$(grep -c "^PASS" lvs_results.txt)
    [ -n "$DEBUG" ] && echo "[INFO] LVS: $N_PASS of $N_CELLS cells match."
    grep "^FAIL" lvs_results.txt | awk '{print $2}' | sort > lvs_fail.txt
    grep -v -e "^#" -e "^$" "$DIR/lvs_known_mismatch.txt" | sort > lvs_known.txt
    NEW_FAIL=$(comm -23 lvs_fail.txt lvs_known.txt)
    NOW_PASS=$(comm -13 lvs_fail.txt lvs_known.txt)
    for c in $NEW_FAIL; do echo "[ERROR] LVS of $c does not match (log <$WORKDIR/$c.lvs.log>)."; done
    for c in $NOW_PASS; do echo "[ERROR] LVS of $c matches now, remove it from lvs_known_mismatch.txt."; done
    [ -z "$NEW_FAIL$NOW_PASS" ] || FAILED="LVS results differ from lvs_known_mismatch.txt"
fi

# A wrong fin count must not match
if [ -z "$FAILED" ]; then
    awk '/^\.SUBCKT INVx1_ASAP7_75t_R /{f=1} f&&/nmos_rvt/{sub(/nfin=3/,"nfin=4")} /^\.ENDS/{f=0} {print}' "$CDL" > wrong_nfin.cdl
    klayout -b -r "$LVS" -rd input="$GDS" -rd topcell=INVx1_ASAP7_75t_R -rd schematic="$PWD/wrong_nfin.cdl" \
        -rd report="$PWD/wrong_nfin.lvsdb" > wrong_nfin.log 2>&1
    grep -q "netlists do not match" wrong_nfin.log || FAILED="LVS matched INVx1 against a CDL with the wrong fin count"
fi

# DRC of INVx1: report written to -rd report=, only ACTIVE.LUP.1
if [ -z "$FAILED" ]; then
    klayout -b -r "$DRC" -rd input="$GDS" -rd topcell=INVx1_ASAP7_75t_R -rd report=inv.lyrdb -rd threads=2 \
        > drc.log 2>&1 || FAILED="KLayout DRC exited with an error"
fi
if [ -z "$FAILED" ]; then
    if [ ! -f "$WORKDIR/inv.lyrdb" ]; then
        FAILED="the DRC deck did not write its report to -rd report="
    else
        CATS=$(python3 - "$WORKDIR/inv.lyrdb" <<'PY'
import sys
import klayout.rdb as rdb
r = rdb.ReportDatabase()
r.load(sys.argv[1])
print(" ".join(sorted({r.category_by_id(i.category_id()).name() for i in r.each_item()})))
PY
)
        [ "$CATS" = "ACTIVE.LUP.1" ] || FAILED="DRC of INVx1 reports <$CATS> instead of ACTIVE.LUP.1 only"
    fi
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
