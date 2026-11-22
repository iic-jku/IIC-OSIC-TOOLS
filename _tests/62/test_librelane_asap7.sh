#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run the LibreLane example of the ASAP7 PDK (libs.tech/librelane/example, an
# 8-bit counter at 1 GHz) and check the result:
# * the flow finishes without errors, with ASAP7 cells in the netlist, no
#   routing DRC errors, no setup or hold violations, and a KLayout DRC result
#   (its count is not checked, see the example README)
# * KLayout LVS of the final GDS against the CDL written by OpenROAD matches
#   (needs fix_asap7_cdl.py: without the tap cell subcircuits write_cdl
#   stops, and without SETN/RESETN the flip-flop pins stay unconnected)
# * the same LVS with two nets swapped in the CDL does not match

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="LibreLane and KLayout LVS with asap7"
WORKDIR=${RUNS_DIR}/${RAND}/62
LOG=$WORKDIR/librelane.log
STDERR_LOG=$WORKDIR/librelane.stderr.log
mkdir -p "$WORKDIR"

if ! command -v librelane > /dev/null 2>&1; then
    echo "[ERROR] Test <$TEST_NAME> FAILED. LibreLane is not installed!"
    exit 1
fi

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
CDL="$PDK_ROOT/asap7/libs.ref/asap7sc7p5t/cdl/asap7sc7p5t_28_R.cdl"
LVS="$PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs"
FAILED=""

cp "$PDK_ROOT"/asap7/libs.tech/librelane/example/{config.json,counter.v} "$WORKDIR"
cd "$WORKDIR" || exit 1
librelane config.json > "$LOG" 2> "$STDERR_LOG"
LL_RC=$?
[ "$LL_RC" -eq 0 ] || FAILED="librelane exited with $LL_RC"

if [ -z "$FAILED" ] && grep -q "ERROR" "$LOG"; then
    FAILED="ERROR in the stdout log"
fi
if [ -z "$FAILED" ] && grep -q "Traceback (most recent call last)" "$STDERR_LOG"; then
    FAILED="Python traceback in the stderr log"
fi
RUN=$(find "$WORKDIR/runs" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null)
if [ -z "$FAILED" ] && [ ! -f "$RUN/final/metrics.json" ]; then
    FAILED="the flow produced no final/metrics.json"
fi
if [ -z "$FAILED" ] && ! grep -q "_ASAP7_75t_R" "$RUN/final/nl/counter.nl.v"; then
    FAILED="the final netlist has no ASAP7 RVT cells"
fi
if [ -z "$FAILED" ]; then
    METRICS=$(python3 - "$RUN/final/metrics.json" <<'PY'
import json
import sys
m = json.load(open(sys.argv[1]))
errors = []
if m.get("route__drc_errors") != 0:
    errors.append(f"route__drc_errors = {m.get('route__drc_errors')}")
for key in ("timing__setup__ws", "timing__hold__ws"):
    if m.get(key) is None or m[key] < 0:
        errors.append(f"{key} = {m.get(key)}")
if "klayout__drc_error__count" not in m:
    errors.append("no klayout__drc_error__count, KLayout DRC did not run")
print("; ".join(errors))
PY
)
    [ -z "$METRICS" ] || FAILED="$METRICS"
fi

# LVS with the CDL OpenROAD writes from the final database
run_lvs() {
    klayout -b -r "$LVS" -rd input="$RUN/final/gds/counter.gds" -rd topcell=counter \
        -rd schematic="$WORKDIR/$1" -rd report="$WORKDIR/${1%.cdl}.lvsdb" > "$WORKDIR/${1%.cdl}.log" 2>&1
}
if [ -z "$FAILED" ]; then
    printf 'read_db %s\nwrite_cdl -include_fillers -masters %s %s\n' \
        "$RUN/final/odb/counter.odb" "$CDL" "$WORKDIR/counter.cdl" > write_cdl.tcl
    openroad -exit -no_init write_cdl.tcl > write_cdl.log 2>&1
    if grep -q "ERROR" write_cdl.log || [ ! -s counter.cdl ]; then
        FAILED="OpenROAD write_cdl failed"
    fi
fi
if [ -z "$FAILED" ]; then
    cat counter.cdl "$CDL" > counter_lvs.cdl
    run_lvs counter_lvs.cdl
    grep -q "netlists match" counter_lvs.log || FAILED="LVS of the final GDS does not match"
fi
if [ -z "$FAILED" ]; then
    # swap count[0] and count[1] on the instances, keep the subcircuit ports
    python3 - counter_lvs.cdl counter_swapped.cdl <<'PY'
import re
import sys
swap = {"count[0]": "count[1]", "count[1]": "count[0]"}
out, in_top, in_header = [], False, False
for line in open(sys.argv[1]).read().split("\n"):
    if line.startswith(".SUBCKT counter "):
        in_top, in_header = True, True
    elif in_header and not line.startswith("+"):
        in_header = False
    if in_top and line.startswith(".ENDS"):
        in_top = False
    if in_top and not in_header:
        line = re.sub(r"count\[[01]\]", lambda m: swap[m.group(0)], line)
    out.append(line)
open(sys.argv[2], "w").write("\n".join(out))
PY
    run_lvs counter_swapped.cdl
    grep -q "netlists do not match" counter_swapped.log || FAILED="LVS matched a CDL with two outputs swapped"
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
