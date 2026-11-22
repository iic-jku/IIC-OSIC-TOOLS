#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test the digital-only ICS55 PDK: LibreLane on a counter, then KLayout DRC
# and the KLayout LVS deck on the result through sak-drc and sak-lvs. The LVS
# has to match the netlist of the design and must not match a netlist with
# one connection changed.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}
WORKDIR=${RUNS_DIR}/${RAND}/59
LOG=$WORKDIR/result_ll_ics55.log
STDERR_LOG=$WORKDIR/result_ll_ics55.stderr.log
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="LibreLane, KLayout DRC and LVS with ics55"

fail() {
    echo "[ERROR] Test <$NAME> FAILED ($1). Check the logs in <$WORKDIR>."
    exit 1
}

command -v librelane >/dev/null 2>&1 || fail "LibreLane is not installed"

mkdir -p "$WORKDIR"
find "$DIR" -maxdepth 1 -type f -exec cp {} "$WORKDIR" \;
cd "$WORKDIR" || fail "cannot enter $WORKDIR"

# shellcheck source=/dev/null
source sak-pdk-script.sh ics55 ics55_LLSC_H7CR > /dev/null
[ "$PDK" = "ics55" ] || fail "sak-pdk did not select ics55"

# The config removes the Magic, Netgen and SPEF steps, which ics55 cannot run.
librelane --manual-pdk "$WORKDIR/counter.json" > "$LOG" 2> "$STDERR_LOG"
LL_RC=$?
[ "$LL_RC" -eq 0 ] || fail "librelane exited with $LL_RC"
grep -q "ERROR" "$LOG" && fail "ERROR in the stdout log"
grep -q "Traceback (most recent call last)" "$STDERR_LOG" && fail "Python traceback in the stderr log"
FINAL=$(find "$WORKDIR/runs" -maxdepth 2 -type d -name final -print -quit 2>/dev/null)
[ -n "$FINAL" ] && [ -f "$FINAL/metrics.json" ] || fail "the flow produced no final/metrics.json"
# KLayout.DRC ran with the community deck and wrote a report (it finds
# violations, which the config does not treat as an error).
find "$WORKDIR/runs" -path "*klayout-drc/reports/drc.klayout.lyrdb" | grep -q . || fail "no KLayout DRC report of the flow"

cp "$FINAL/gds/counter.gds" "$WORKDIR/counter.gds"

# sak-drc runs the community deck directly.
sak-drc.sh -k -w "$WORKDIR/drc" counter > "$WORKDIR/sak-drc.log" 2>&1
DRC_RC=$?
# 0 is clean, 1 are violations, everything else is a failed run
[ "$DRC_RC" -le 1 ] || fail "sak-drc exited with $DRC_RC"

# CDL of the routed design, with the standard-cell CDL appended
CELL_CDL="$PDKPATH/libs.ref/$STD_CELL_LIBRARY/cdl/$STD_CELL_LIBRARY.cdl"
printf 'read_db %s\nwrite_cdl -masters %s %s\n' "$FINAL/odb/counter.odb" "$CELL_CDL" "$WORKDIR/counter_top.cdl" > "$WORKDIR/write_cdl.tcl"
openroad -exit -no_init "$WORKDIR/write_cdl.tcl" > "$WORKDIR/write_cdl.log" 2>&1 || fail "OpenROAD write_cdl failed"
cat "$WORKDIR/counter_top.cdl" "$CELL_CDL" > "$WORKDIR/counter.cdl"

sak-lvs.sh -k -w "$WORKDIR/lvs" -s "$WORKDIR/counter.cdl" -l "$WORKDIR/counter.gds" -c counter > "$WORKDIR/sak-lvs.log" 2>&1 \
    || fail "KLayout LVS does not match"

# Swap the two inputs of the first AND2 instance, which LVS has to catch.
awk '!done && /^X.* AND2X[0-9P]*H7R$/ { t = $2; $2 = $3; $3 = t; done = 1 } { print }' \
    "$WORKDIR/counter.cdl" > "$WORKDIR/counter_bad.cdl"
cmp -s "$WORKDIR/counter.cdl" "$WORKDIR/counter_bad.cdl" && fail "no AND2 instance to change for the negative check"
sak-lvs.sh -k -w "$WORKDIR/lvs_bad" -s "$WORKDIR/counter_bad.cdl" -l "$WORKDIR/counter.gds" -c counter > "$WORKDIR/sak-lvs-bad.log" 2>&1
BAD_RC=$?
# 1 is a mismatch, everything else is a failed run
[ "$BAD_RC" -eq 1 ] || fail "KLayout LVS of the changed netlist exited with $BAD_RC, expected a mismatch (1)"

echo "[INFO] Test <$NAME> passed."
exit 0
