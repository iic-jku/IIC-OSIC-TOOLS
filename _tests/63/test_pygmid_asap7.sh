#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Generate gm/ID lookup tables for the ASAP7 RVT devices with
# libs.tech/pygmid/techsweep_asap7.py (ngspice) in the .mat layout of the
# analog-circuit-design course and read them with pygmid like the course does:
# * every field of the course tables is there
# * ID at |VGS| = |VDS| = 0.7 V agrees with a direct ngspice operating point
#   within 1 %, and gm/ID falls with VGS from weak to strong inversion
# * the thermal noise STH is 0.5 to 3 times 4kT gm in saturation, and the
#   flicker noise SFL at 1 Hz is above it

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="pygmid lookup tables for asap7"
WORKDIR=${RUNS_DIR}/${RAND}/63
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
SWEEP="$PDK_ROOT/asap7/libs.tech/pygmid/techsweep_asap7.py"
FAILED=""

for d in nmos_rvt pmos_rvt; do
    python3 "$SWEEP" --device "$d" --step 0.05 --vsb 0,0.2 > "sweep_$d.log" 2>&1 || { FAILED="techsweep for $d failed"; break; }
    # direct operating point at full bias
    v=0.7; [[ $d == pmos* ]] && v=-0.7
    printf '* op\n.lib %s/asap7/libs.tech/ngspice/models/asap7.lib tt\n.temp 27\nvd d 0 %s\nvg g 0 %s\nx1 d g 0 0 %s l=0.02u nfin=1\n.control\nop\nprint i(vd)\n.endc\n.end\n' \
        "$PDK_ROOT" "$v" "$v" "$d" > "op_$d.sp"
    ngspice -b "op_$d.sp" 2>&1 | sed -n 's/^i(vd) *= *//p' > "op_$d.txt"
done

if [ -z "$FAILED" ]; then
    CHECK=$(python3 - <<'PY'
import numpy as np
from pygmid import Lookup
errors = []
fields = "INFO CORNER TEMP VGS VDS VSB L W NFING ID VT GM GMB GDS CGG CGB CGD CGS CDD CSS STH SFL".split()
k_t = 1.380649e-23 * 300.15
for d in ("nmos_rvt", "pmos_rvt"):
    lk = Lookup(f"asap7_{d}.mat")
    missing = [f for f in fields if f not in lk]
    if missing:
        errors.append(f"{d}: fields missing in the table: {missing}")
        continue
    id_lk = float(lk.lookup("ID", L=0.02, VGS=0.7, VDS=0.7, VSB=0))
    id_op = abs(float(open(f"op_{d}.txt").read()))
    gm_id = lk.lookup("GM_ID", L=0.02, VGS=np.array([0.2, 0.4, 0.6]), VDS=0.35, VSB=0)
    gamma = float(lk.lookup("STH", VGS=0.6, VDS=0.35) / (4 * k_t * lk.lookup("GM", VGS=0.6, VDS=0.35)))
    sfl = float(lk.lookup("SFL", VGS=0.6, VDS=0.35))
    sth = float(lk.lookup("STH", VGS=0.6, VDS=0.35))
    print(f"[INFO] {d}: ID lookup {id_lk * 1e6:.2f} uA, op {id_op * 1e6:.2f} uA, gm/ID at VGS 0.2/0.4/0.6 V = {np.round(gm_id, 1)},"
          f" STH/(4kT gm) = {gamma:.2f}, SFL(1 Hz) = {sfl:.2e} A^2/Hz")
    if abs(id_lk / id_op - 1) > 0.01:
        errors.append(f"{d}: lookup ID {id_lk:.4e} A differs from the operating point {id_op:.4e} A by more than 1 %")
    if not (gm_id[0] > gm_id[1] > gm_id[2] > 0):
        errors.append(f"{d}: gm/ID does not fall with VGS ({gm_id})")
    if not 0.5 <= gamma <= 3.0:
        errors.append(f"{d}: STH is {gamma:.2f} times 4kT gm")
    if not sfl > sth:
        errors.append(f"{d}: SFL at 1 Hz ({sfl:.2e}) is not above STH ({sth:.2e})")
for e in errors:
    print(f"[ERROR] {e}")
print("RESULT", "FAIL" if errors else "PASS")
PY
)
    [ -n "$DEBUG" ] && echo "$CHECK"
    echo "$CHECK" | grep "^\[ERROR\]"
    echo "$CHECK" | grep -q "^RESULT PASS" || FAILED="lookup check failed"
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
