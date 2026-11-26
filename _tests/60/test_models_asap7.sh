#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Check the ASAP7 FinFET models in ngspice, Xyce and VACASK against the typical
# per-fin targets of the ASAP7 paper (Clark et al., Microelectronics Journal 53,
# 2016, tables 3 and 4: Idsat at |VGS| = |VDS| = 0.7 V, Ioff at VGS = 0, 25 C).
#
# * Xyce runs the cards natively (BSIM-CMG 107), so it has to hit the paper
#   Idsat within 2 %.
# * ngspice and VACASK load BSIM-CMG 107 as OSDI and run the same cards, so
#   they have to agree with Xyce within 0.5 % on Idsat and within 2 % on Ioff.
#   Ioff may differ by 0.1 pA more: the pmos_sram Ioff of 4 pA is close to
#   the default ngspice abstol of 1 pA.
# * The xschem inverter testbenches for ngspice and Xyce netlist and simulate,
#   and so does the VACASK example, all with the switching point between
#   0.30 V and 0.40 V.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="ASAP7 models in ngspice, Xyce and VACASK"
WORKDIR=${RUNS_DIR}/${RAND}/60
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
LIBS="$PDK_ROOT/asap7/libs.tech"
FAILED=""

DEVS="nmos_sram nmos_rvt nmos_lvt nmos_slvt pmos_sram pmos_rvt pmos_lvt pmos_slvt"

# One deck per simulator and bias point (off: VGS = 0, on: VGS = VDS), one
# device per drain source, 1 fin each.
for phase in off on; do
    {
        echo "* ASAP7 Ion/Ioff ($phase)"
        echo ".lib $LIBS/ngspice/models/asap7.lib tt"
        echo ".temp 25"
        i=0
        for d in $DEVS; do
            v=0.7; [[ $d == pmos* ]] && v=-0.7
            vg=0; [ $phase = on ] && vg=$v
            echo "vd$i d$i 0 $v"
            echo "vg$i g$i 0 $vg"
            echo "x$i d$i g$i 0 0 $d nfin=1"
            i=$((i + 1))
        done
        echo ".control"
        echo "op"
        i=0
        for d in $DEVS; do echo "print i(vd$i)"; i=$((i + 1)); done
        echo ".endc"
        echo ".end"
    } > "ng_$phase.sp"
    ngspice -b "ng_$phase.sp" > "ng_$phase.log" 2>&1 || FAILED="ngspice failed ($phase)"
    grep -E "^i\(vd" "ng_$phase.log" | sed 's/.*= *//' > "ng_$phase.txt"

    {
        echo "* ASAP7 Ion/Ioff ($phase)"
        echo ".lib $LIBS/xyce/models/asap7.lib tt"
        echo ".options device temp=25"
        i=0
        for d in $DEVS; do
            v=0.7; [[ $d == pmos* ]] && v=-0.7
            vg=0; [ $phase = on ] && vg=$v
            echo "vd$i d$i 0 $v"
            echo "vg$i g$i 0 $vg"
            echo "x$i d$i g$i 0 0 $d nfin=1"
            i=$((i + 1))
        done
        echo ".dc vd0 0.7 0.7 0.1"
        echo -n ".print dc format=noindex file=xy_$phase.txt"
        i=0
        for d in $DEVS; do echo -n " {i(vd$i)}"; i=$((i + 1)); done
        echo
        echo ".end"
    } > "xy_$phase.cir"
    Xyce "xy_$phase.cir" > "xy_$phase.log" 2>&1 || FAILED="Xyce failed ($phase)"

    {
        echo "ASAP7 Ion/Ioff ($phase)"
        echo "ground 0"
        echo "include \"asap7.lib\" section=tt"
        echo "model vsource vsource"
        i=0
        for d in $DEVS; do
            v=0.7; [[ $d == pmos* ]] && v=-0.7
            vg=0; [ $phase = on ] && vg=$v
            echo "vd$i (d$i 0) vsource dc=$v"
            echo "vg$i (g$i 0) vsource dc=$vg"
            echo "x$i (d$i g$i 0 0) $d nfin=1"
            i=$((i + 1))
        done
        echo "control"
        echo "  options temp=25"
        echo "  analysis vc_$phase op"
        echo "endc"
    } > "vc_$phase.sim"
    vacask "vc_$phase.sim" > "vc_$phase.log" 2>&1 || FAILED="VACASK failed ($phase)"
done

if [ -z "$FAILED" ]; then
    CHECK=$(python3 - <<'PY'
import re
import numpy as np
try:
    from vacask.rawfile import rawread
except ImportError:
    from rawfile import rawread

devs = "nmos_sram nmos_rvt nmos_lvt nmos_slvt pmos_sram pmos_rvt pmos_lvt pmos_slvt".split()
# paper: Idsat in uA, Ioff in nA (per fin)
paper = {
    "nmos_sram": (28.57, 0.001), "nmos_rvt": (37.85, 0.019), "nmos_lvt": (45.19, 0.242), "nmos_slvt": (50.79, 2.444),
    "pmos_sram": (26.90, 0.004), "pmos_rvt": (32.88, 0.023), "pmos_lvt": (39.88, 0.230), "pmos_slvt": (45.60, 2.410),
}

def ng(phase):
    return [abs(float(x)) for x in open(f"ng_{phase}.txt").read().split()]

def xy(phase):
    rows = [l for l in open(f"xy_{phase}.txt") if re.match(r"\s*[-+0-9]", l)]
    return [abs(float(x)) for x in rows[0].split()]

def vc(phase):
    r = rawread(f"vc_{phase}.raw").get()
    return [abs(float(np.ravel(r[f"vd{i}:flow(br)"])[0])) for i in range(len(devs))]

res = {sim: {p: f(p) for p in ("on", "off")} for sim, f in (("ngspice", ng), ("xyce", xy), ("vacask", vc))}
errors = []
for i, d in enumerate(devs):
    idsat, ioff = paper[d]
    ion = {s: res[s]["on"][i] * 1e6 for s in res}
    iof = {s: res[s]["off"][i] * 1e9 for s in res}
    print(f"[INFO] {d:9s} Idsat uA paper {idsat:6.2f} xyce {ion['xyce']:6.2f} ngspice {ion['ngspice']:6.2f} vacask {ion['vacask']:6.2f}"
          f" | Ioff nA paper {ioff:6.3f} xyce {iof['xyce']:6.3f} ngspice {iof['ngspice']:6.3f} vacask {iof['vacask']:6.3f}")
    if abs(ion["xyce"] / idsat - 1) > 0.02:
        errors.append(f"{d}: Xyce Idsat {ion['xyce']:.2f} uA off the paper's {idsat} uA by more than 2 %")
    for s in ("ngspice", "vacask"):
        if abs(ion[s] / ion["xyce"] - 1) > 0.005:
            errors.append(f"{d}: {s} Idsat {ion[s]:.3f} uA differs from Xyce ({ion['xyce']:.3f} uA) by more than 0.5 %")
        if abs(iof[s] - iof["xyce"]) > 0.02 * iof["xyce"] + 1e-4:
            errors.append(f"{d}: {s} Ioff {iof[s]:.4f} nA differs from Xyce ({iof['xyce']:.4f} nA) by more than 2 %")
for e in errors:
    print(f"[ERROR] {e}")
print("RESULT", "FAIL" if errors else "PASS")
PY
)
    [ -n "$DEBUG" ] && echo "$CHECK"
    echo "$CHECK" | grep "^\[ERROR\]"
    echo "$CHECK" | grep -q "^RESULT PASS" || FAILED="currents off target"
fi

# xschem testbenches and the VACASK example
vm_ok() {
    python3 -c "import sys; v = float(sys.argv[1]); sys.exit(0 if 0.30 <= v <= 0.40 else 1)" "$1" 2> /dev/null
}
if [ -z "$FAILED" ]; then
    TB_DIR="$LIBS/xschem/asap7_tests"
    for tb in inv_vtc_ngspice inv_vtc_xyce; do
        xschem -q -x -n -s --rcfile "$LIBS/xschem/xschemrc" -o "$WORKDIR" "$TB_DIR/$tb.sch" > "$tb.xschem.log" 2>&1
        [ -f "$tb.spice" ] || { FAILED="xschem did not netlist $tb"; break; }
    done
fi
if [ -z "$FAILED" ]; then
    VM=$(ngspice -b inv_vtc_ngspice.spice 2>&1 | tee inv_vtc_ngspice.log | sed -n 's/^vm *= *//p' | head -1)
    vm_ok "$VM" || FAILED="ngspice inverter switching point <$VM> not within 0.30 V to 0.40 V"
fi
if [ -z "$FAILED" ]; then
    VM=$(Xyce inv_vtc_xyce.spice 2>&1 | tee inv_vtc_xyce.log | sed -n 's/^VM *= *//p' | head -1)
    vm_ok "$VM" || FAILED="Xyce inverter switching point <$VM> not within 0.30 V to 0.40 V"
fi
if [ -z "$FAILED" ]; then
    cp "$LIBS/vacask/examples/inv_vtc.sim" .
    VM=$(vacask inv_vtc.sim 2>&1 | tee inv_vtc_vacask.log | sed -n 's/^switching point vm = \([0-9.]*\) V/\1/p')
    vm_ok "$VM" || FAILED="VACASK inverter switching point <$VM> not within 0.30 V to 0.40 V"
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
