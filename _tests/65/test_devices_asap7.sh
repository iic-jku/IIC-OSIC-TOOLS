#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Passive devices that IIC-OSIC-TOOLS adds to ASAP7 (metal resistors rm<n>,
# thin-film resistor rtfr, MOM capacitor cmom_m<bot>m<top>, MOS capacitors):
# * ngspice, Xyce and VACASK have to give the resistance and capacitance of
#   the formulas in asap7_passives.json within 0.1 %, at 27 C and at 127 C
#   (temperature coefficients), with the multiplier m and in the ss corner.
#   This includes the capacitance of rtfr to its substrate terminal.
# * rtfr with mm=1 runs in all three simulators, and 400 instances in ngspice
#   spread by the sigma of the area law within 20 %. The same holds for the
#   threshold mismatch of a FinFET with mm=1 (gate voltage of 400
#   diode-connected devices at 1 uA).
# * A MOS capacitor (FinFET with m=10) has to read the same in ngspice and
#   VACASK within 0.5 % and ten times the single device.
# * The xschem testbench passives_ngspice.sch netlists and simulates.
# * The layouts of asap7_layout.py pass KLayout LVS against the device
#   call and are DRC clean. A wrong length or footprint in the schematic
#   and a finger cut out of a capacitor must not match.
# * Each passive rule group of the DRC deck fires on a layout that breaks it.
# * FinFET and MOS capacitor layouts of asap7_layout.py match their device
#   call (nfin, and the fingers as m) and violate only the latch-up tap rule
#   ACTIVE.LUP.1, like a standard cell on its own. A wrong fin count fails.
# * KLayout registers the PCell library ASAP7 with one PCell per device, and
#   a cell of each PCell passes LVS and DRC the same way.
# * A FinFET next to the tap PCell of its row is DRC clean, and with
#   -rd body=true its body compares as the net of the tap.
# * Longer gates and the 1.8 V IO FinFETs: layouts match their device call
#   with the gate length, a gate length outside the set violates GATE.W.1,
#   the IO FinFETs reach 0.92 and 0.80 mA/um at 1.8 V within 10 % in ngspice,
#   Xyce and VACASK (Intel 22 nm SoC, IEDM 2012), and the intrinsic gain
#   rises with the gate length.
# * -rd pex= writes a netlist with wire capacitances: 10 um of two M2 wires
#   at minimum spacing give the coupling and substrate capacitance of the
#   OpenRCX rules, and the netlist simulates in ngspice.
# * Junction diodes ndio and pdio and the vertical PNP pnp: the same forward
#   voltage in ngspice, Xyce and VACASK within 1 mV, a negative temperature
#   coefficient, and the difference between 1 and 8 strips at one current is
#   n kT/q ln 8, the voltage a bandgap reference is built on. Their layouts
#   and PCells pass LVS by area and are DRC clean, a swapped base and emitter
#   and a wrong area do not match.
# * -rd pex_res=true adds the wire resistance: 9.9 um of minimum-width M2
#   read 294 Ohm, and the example still amplifies with its wire resistors.
# * The pad PCell and generator cell is DRC clean, connects through V9 to
#   its M9 stripes (LVS with an rm9 on a stripe) and extracts as capacitance.
# * The routed example asap7_example.py (common-source amplifier with FinFET,
#   tap, thin-film resistor and MOM capacitor) is DRC clean, matches its
#   netlist with body=true, and its extracted netlist amplifies in ngspice.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TEST_NAME="ASAP7 analog devices: models, layouts, PCells, LVS and DRC"
WORKDIR=${RUNS_DIR}/${RAND}/65
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# shellcheck source=/dev/null
source sak-pdk-script.sh asap7 > /dev/null
LIBS="$PDK_ROOT/asap7/libs.tech"
PAR="$LIBS/klayout/tech/asap7_passives.json"
GEN="$LIBS/klayout/python/asap7_layout.py"
LVS="$LIBS/klayout/lvs/asap7.lvs"
DRC="$LIBS/klayout/drc/asap7.lydrc"
FAILED=""

# ---------------------------------------------------------------------------
# Models: one deck per simulator, corner and temperature. Every device hangs
# on its own 1 V source, resistors are read at DC, capacitors at 1 MHz.
# ---------------------------------------------------------------------------
# name, device call
DUTS="rm2:rm2 w=18n l=1.8u
rm8:rm8 w=80n l=4u m=2
rtfr:rtfr w=108n l=1u
rtfr2:rtfr w=216n l=5u m=3
rtfrmm:rtfr w=1u l=10u mm=1
cm47:cmom_m4m7 w=1u l=2u
cm13:cmom_m1m3 w=0.5u l=0.5u m=4
cm17:cmom_m1m7 w=3u l=3u"
NAMES=$(echo "$DUTS" | cut -d: -f1 | tr '\n' ' ')

for run in tt_27 tt_127 ss_27; do
    corner=${run%_*}
    temp=${run#*_}
    {
        echo "* ASAP7 passives $run"
        echo ".lib $LIBS/ngspice/models/asap7.lib $corner"
        echo ".temp $temp"
        echo "$DUTS" | while IFS=: read -r n call; do
            echo "v$n $n 0 dc 1 ac 1"
            # rtfr has the substrate as third terminal
            b=""; [[ $call == rtfr* ]] && b=" 0"
            echo "x$n $n 0$b $call"
        done
        echo "vcap1 cap1 0 dc 0.7 ac 1"
        echo "xcap1 0 cap1 0 0 nmos_rvt nfin=4"
        echo "vcap10 cap10 0 dc 0.7 ac 1"
        echo "xcap10 0 cap10 0 0 nmos_rvt nfin=4 m=10"
        echo "xmm 0 rm2 0 0 pmos_lvt nfin=2 mm=1"
        echo ".control"
        echo "op"
        for n in $NAMES; do echo "print -i(v$n)"; done
        echo "ac lin 1 1meg 1meg"
        for n in $NAMES cap1 cap10; do echo "print -imag(i(v$n))"; done
        echo ".endc"
        echo ".end"
    } > "ng_$run.sp"
    ngspice -b "ng_$run.sp" > "ng_$run.log" 2>&1 || FAILED="ngspice failed ($run)"

    {
        echo "* ASAP7 passives $run"
        echo ".lib $LIBS/xyce/models/asap7.lib $corner"
        echo ".options device temp=$temp"
        echo "$DUTS" | while IFS=: read -r n call; do
            echo "v$n $n 0 dc 1 ac 1"
            # rtfr has the substrate as third terminal
            b=""; [[ $call == rtfr* ]] && b=" 0"
            echo "x$n $n 0$b $call"
        done
        echo "xmm 0 rm2 0 0 pmos_lvt nfin=2 mm=1"
        echo ".ac lin 1 1meg 1meg"
        echo -n ".print ac format=noindex file=xy_$run.txt"
        for n in $NAMES; do echo -n " {-ir(v$n)} {-ii(v$n)}"; done
        echo
        echo ".end"
    } > "xy_$run.cir"
    Xyce "xy_$run.cir" > "xy_$run.log" 2>&1 || FAILED="Xyce failed ($run)"

    {
        echo "ASAP7 passives $run"
        echo "ground 0"
        echo "include \"asap7.lib\" section=$corner"
        echo "model vsource vsource"
        echo "$DUTS" | while IFS=: read -r n call; do
            echo "v$n ($n 0) vsource dc=1 mag=1"
            b=""; [[ $call == rtfr* ]] && b=" 0"
            echo "x$n ($n 0$b) $call"
        done
        echo "vcap1 (cap1 0) vsource dc=0.7 mag=1"
        echo "xcap1 (0 cap1 0 0) nmos_rvt nfin=4"
        echo "vcap10 (cap10 0) vsource dc=0.7 mag=1"
        echo "xcap10 (0 cap10 0 0) nmos_rvt nfin=4 m=10"
        echo "xmm (0 rm2 0 0) pmos_lvt nfin=2 mm=1"
        echo "control"
        echo "  options temp=$temp"
        echo "  analysis vcop_$run op"
        echo "  analysis vcac_$run ac from=1e6 to=1e6 mode=\"lin\" points=1"
        echo "endc"
    } > "vc_$run.sim"
    vacask "vc_$run.sim" > "vc_$run.log" 2>&1 || FAILED="VACASK failed ($run)"
done

# Mismatch of rtfr: 400 instances with mm=1 in ngspice
{
    echo "* ASAP7 rtfr mismatch"
    echo ".lib $LIBS/ngspice/models/asap7.lib tt"
    echo "v1 a 0 dc 1"
    for i in $(seq 400); do echo "x$i a n$i 0 rtfr w=108n l=1u mm=1"; echo "vm$i n$i 0 0"; done
    echo ".control"
    echo "op"
    echo "print all"
    echo ".endc"
    echo ".end"
} > ng_mm.sp
ngspice -b ng_mm.sp > ng_mm.log 2>&1 || FAILED="ngspice failed (mismatch)"

# Mismatch of a FinFET: 400 diode-connected nmos_rvt with mm=1 at 1 uA
{
    echo "* ASAP7 FinFET mismatch"
    echo ".lib $LIBS/ngspice/models/asap7.lib tt"
    for i in $(seq 400); do echo "i$i 0 g$i 1u"; echo "x$i g$i g$i 0 0 nmos_rvt nfin=3 mm=1"; done
    echo ".control"
    echo "op"
    echo "print all"
    echo ".endc"
    echo ".end"
} > ng_mmfet.sp
ngspice -b ng_mmfet.sp > ng_mmfet.log 2>&1 || FAILED="ngspice failed (FinFET mismatch)"

if [ -z "$FAILED" ]; then
    CHECK=$(python3 - "$PAR" "$DUTS" <<'PY'
import json
import math
import re
import sys
import numpy as np
try:
    from vacask.rawfile import rawread
except ImportError:
    from rawfile import rawread

par = json.load(open(sys.argv[1]))
duts = [l.split(":") for l in sys.argv[2].splitlines()]
names = [d[0] for d in duts]
W = 2 * math.pi * 1e6
SI = {"n": 1e-9, "u": 1e-6}

def num(s):
    return float(s[:-1]) * SI[s[-1]] if s[-1] in SI else float(s)

def mom_cap(bot, top, w, l):
    c = 0.0
    for n in range(bot, top + 1):
        m = par["metals"][str(n)]
        pitch = m["wmin"] + m["smin"]
        across, along = (l, w) if m["dir"] == "H" else (w, l)
        nf = 2 * math.floor((across - 2 * par["mom_edge"] + m["smin"] + 1e-9) / (2 * pitch))
        c += m["cc"] * 1e-15 * along * max(nf - 1, 0)
    return c

def expected(call, corner, temp, kind=None):
    """Resistance in Ohm or capacitance in F of a device call.

    kind "Csub" is the capacitance of one end of rtfr to its substrate.
    """
    model, *args = call.split()
    p = {k: num(v) for k, v in (a.split("=") for a in args)}
    w, l, mult = p["w"] * 1e6, p["l"] * 1e6, p.get("m", 1)
    f = par["corners"][corner]
    dt = temp - par["tnom"]
    if kind == "Csub":
        t = par["tfr"]
        return kind, f["ctfr"] * (0.5 * t["ca"] * w * l + t["cp"] * (w + l)) * 1e-15 * mult
    if model.startswith("cmom"):
        bot, top = (int(x) for x in re.match(r"cmom_m(\d)m(\d)", model).groups())
        return "C", mom_cap(bot, top, w, l) * f["cmom"] * mult
    if model == "rtfr":
        t = par["tfr"]
        r = (t["rsh"] * l + 2 * t["rend"]) / w * f["rtfr"]
        tc1, tc2 = t["tc1"], t["tc2"]
    else:
        r = par["metals"][model[2:]]["rsh"] * l / w * f["rm"]
        tc1, tc2 = par["rm"]["tc1"], par["rm"]["tc2"]
    return "R", r * (1 + tc1 * dt + tc2 * dt * dt) / mult

def ngspice(run):
    v = [float(x) for x in re.findall(r"^-(?:imag\()?i\(v\w+\)+ = (\S+)", open(f"ng_{run}.log").read(), re.M)]
    n = len(names)
    return dict(zip(names, v[:n])), dict(zip(names + ["cap1", "cap10"], v[n:]))

def xyce(run):
    rows = [l for l in open(f"xy_{run}.txt") if re.match(r"\s*[-+0-9]", l)]
    v = [float(x) for x in rows[0].split()[1:]]
    return dict(zip(names, v[0::2])), dict(zip(names, v[1::2]))

def vacask(run):
    op = rawread(f"vcop_{run}.raw").get()
    ac = rawread(f"vcac_{run}.raw").get()
    cur = lambda r, n: np.ravel(r[f"v{n}:flow(br)"])[0]
    return ({n: -float(np.real(cur(op, n))) for n in names},
            {n: -float(np.imag(cur(ac, n))) for n in names + ["cap1", "cap10"]})

errors = []
for run in ("tt_27", "tt_127", "ss_27"):
    corner, temp = run.split("_")
    res = {"ngspice": ngspice(run), "xyce": xyce(run), "vacask": vacask(run)}
    checks = [(n, c, None) for n, c in duts] + [(n, c, "Csub") for n, c in duts if c.startswith("rtfr")]
    for name, call, sub in checks:
        kind, want = expected(call, corner, float(temp), sub)
        # a single instance with mismatch is off by its sigma of 0.6 %
        tol = 0.05 if kind == "R" and "mm=1" in call else 1e-3
        for sim, (idc, iac) in res.items():
            got = 1 / idc[name] if kind == "R" else iac[name] / W
            print(f"[INFO] {run} {sim:7s} {name:6s} {kind} = {got:.6g}, expected {want:.6g}")
            if abs(got / want - 1) > tol:
                errors.append(f"{run} {sim} {call}: {kind} = {got:.6g} instead of {want:.6g}")
    # MOS capacitor: m=10 is ten devices, ngspice and VACASK run the same model
    ng, vc = res["ngspice"][1], res["vacask"][1]
    print(f"[INFO] {run} MOS capacitor nfin=4: ngspice {ng['cap1'] / W:.4g} F, VACASK {vc['cap1'] / W:.4g} F")
    if not 1e-18 < ng["cap1"] / W < 1e-15:
        errors.append(f"{run}: MOS capacitor of 4 fins reads {ng['cap1'] / W:.3g} F")
    for sim, c in (("ngspice", ng), ("VACASK", vc)):
        if abs(c["cap10"] / c["cap1"] / 10 - 1) > 1e-3:
            errors.append(f"{run} {sim}: MOS capacitor with m=10 is {c['cap10'] / c['cap1']:.4g} times the single one")
    if abs(ng["cap1"] / vc["cap1"] - 1) > 5e-3:
        errors.append(f"{run}: MOS capacitor differs between ngspice and VACASK by more than 0.5 %")
# Mismatch: sigma(dR/R) = ar / sqrt(w * l) for w = 0.108 um, l = 1 um
i = np.array([float(x) for x in re.findall(r"^vm\d+#branch = (\S+)", open("ng_mm.log").read(), re.M)])
want = par["tfr"]["ar"] / 100 / math.sqrt(0.108 * 1)
got = float(np.std(1 / i) / np.mean(1 / i)) if len(i) == 400 else 0.0
print(f"[INFO] rtfr mismatch of {len(i)} instances: sigma = {got * 100:.2f} %, expected {want * 100:.2f} %")
if abs(got / want - 1) > 0.2:
    errors.append(f"rtfr mismatch: sigma = {got * 100:.2f} % instead of {want * 100:.2f} %")
# FinFET: the gate voltage at a fixed current follows the threshold shift,
# sigma = 1.4 mV um / sqrt(nfin * 70.5 nm * 20 nm)
v = np.array([float(x) for x in re.findall(r"^g\d+ = (\S+)", open("ng_mmfet.log").read(), re.M)])
want = 1.4e-9 / math.sqrt(3 * 70.5e-9 * 20e-9)
got = float(np.std(v)) if len(v) == 400 else 0.0
print(f"[INFO] FinFET mismatch of {len(v)} devices: sigma(VGS) = {got * 1e3:.1f} mV, expected {want * 1e3:.1f} mV")
if abs(got / want - 1) > 0.2:
    errors.append(f"FinFET mismatch: sigma(VGS) = {got * 1e3:.1f} mV instead of {want * 1e3:.1f} mV")
for e in errors:
    print(f"[ERROR] {e}")
print("RESULT", "FAIL" if errors else "PASS")
PY
)
    [ -n "$DEBUG" ] && echo "$CHECK"
    echo "$CHECK" | grep "^\[ERROR\]"
    echo "$CHECK" | grep -q "^RESULT PASS" || FAILED="model values off the formulas"
fi

# IO FinFETs and gate length scaling
if [ -z "$FAILED" ]; then
    {
        echo "* ASAP7 IO FinFETs and gain over length"
        echo ".lib $LIBS/ngspice/models/asap7.lib tt"
        echo ".temp 25"
        echo "vdn dn 0 1.8"
        echo "xn dn dn 0 0 nmos_18 nfin=100"
        echo "vdp dp 0 -1.8"
        echo "xp dp dp 0 0 pmos_18 nfin=100"
        for l in 20 36 80; do
            echo "vg$l g$l 0 0.35"
            echo "vd$l d$l 0 0.35"
            echo "x$l d$l g$l 0 0 nmos_rvt nfin=10 l=${l}n"
        done
        echo ".control"
        echo "op"
        echo "print -i(vdn) i(vdp)"
        for l in 20 36 80; do echo "print -i(vd$l)"; done
        for l in 20 36 80; do echo "alter vd$l 0.36"; done
        echo "op"
        for l in 20 36 80; do echo "print -i(vd$l)"; done
        for l in 20 36 80; do echo "alter vd$l 0.35"; echo "alter vg$l 0.36"; done
        echo "op"
        for l in 20 36 80; do echo "print -i(vd$l)"; done
        echo ".endc"
        echo ".end"
    } > ng_io.sp
    ngspice -b ng_io.sp > ng_io.log 2>&1 || FAILED="ngspice failed (IO FinFETs)"
    {
        echo "* ASAP7 IO FinFETs"
        echo ".lib $LIBS/xyce/models/asap7.lib tt"
        echo ".options device temp=25"
        echo "vdn dn 0 1.8"
        echo "xn dn dn 0 0 nmos_18 nfin=100"
        echo "vdp dp 0 -1.8"
        echo "xp dp dp 0 0 pmos_18 nfin=100"
        echo ".dc vdn 1.8 1.8 0.1"
        echo ".print dc format=noindex file=xy_io.txt {-i(vdn)} {i(vdp)}"
        echo ".end"
    } > xy_io.cir
    Xyce xy_io.cir > xy_io.log 2>&1 || FAILED="Xyce failed (IO FinFETs)"
    {
        echo "ASAP7 IO FinFETs"
        echo "ground 0"
        echo "include \"asap7.lib\" section=tt"
        echo "model vsource vsource"
        echo "vdn (dn 0) vsource dc=1.8"
        echo "xn (dn dn 0 0) nmos_18 nfin=100"
        echo "vdp (dp 0) vsource dc=-1.8"
        echo "xp (dp dp 0 0) pmos_18 nfin=100"
        echo "control"
        echo "  options temp=25"
        echo "  analysis vc_io op"
        echo "endc"
    } > vc_io.sim
    vacask vc_io.sim > vc_io.log 2>&1 || FAILED="VACASK failed (IO FinFETs)"
fi
if [ -z "$FAILED" ]; then
    python3 - <<'PY' > io.check.log 2>&1 || FAILED="IO FinFET currents or gain over length off (see io.check.log)"
import re
import numpy as np
try:
    from vacask.rawfile import rawread
except ImportError:
    from rawfile import rawread

perimeter = 100 * 70.5e-9   # m of fin perimeter of 100 fins
v = [float(x) for x in re.findall(r"^-?i\(v\w+\) = (\S+)", open("ng_io.log").read(), re.M)]
ion = {"ngspice": (v[0], v[1])}
rows = [l for l in open("xy_io.txt") if re.match(r"\s*[-+0-9]", l)]
ion["xyce"] = tuple(float(x) for x in rows[0].split())
r = rawread("vc_io.raw").get()
ion["vacask"] = (-float(np.ravel(r["vdn:flow(br)"])[0]), float(np.ravel(r["vdp:flow(br)"])[0]))
bad = []
for sim, (n, p) in ion.items():
    n, p = abs(n) / perimeter, abs(p) / perimeter   # A/m is mA/mm, 1e-3 of that is mA/um
    print(f"{sim}: nmos_18 {n * 1e-3:.3f} mA/um, pmos_18 {p * 1e-3:.3f} mA/um")
    if abs(n * 1e-3 / 0.92 - 1) > 0.1 or abs(p * 1e-3 / 0.80 - 1) > 0.1:
        bad.append(f"{sim}: IO drive current off 0.92 and 0.80 mA/um by more than 10 %")
i0, i1, i2 = v[2:5], v[5:8], v[8:11]
gain = [(c - a) / (b - a) for a, b, c in zip(i0, i1, i2)]
print("gain of nmos_rvt at 20, 36 and 80 nm:", [round(g, 1) for g in gain])
if not (gain[0] * 2 < gain[1] and gain[1] * 1.3 < gain[2]):
    bad.append(f"the gain of nmos_rvt does not rise with the gate length: {gain}")
for b in bad:
    print("[ERROR]", b)
raise SystemExit(1 if bad else 0)
PY
    [ -n "$DEBUG" ] && cat io.check.log
fi

# xschem testbench: 53.48 Ohm, 5833 Ohm with 0.05 fF per end, 7.454 fF and a
# MOS capacitor
if [ -z "$FAILED" ]; then
    xschem -q -x -n -s --rcfile "$LIBS/xschem/xschemrc" -o "$WORKDIR" \
        "$LIBS/xschem/asap7_tests/passives_ngspice.sch" > passives.xschem.log 2>&1
    [ -f passives_ngspice.spice ] || FAILED="xschem did not netlist passives_ngspice"
fi
if [ -z "$FAILED" ]; then
    ngspice -b passives_ngspice.spice > passives_ngspice.log 2>&1
    python3 - <<'PY' || FAILED="xschem testbench values off"
import re
v = {k: float(x) for k, x in re.findall(r"^(\w+) = (\S+)", open("passives_ngspice.log").read(), re.M)}
want = {"r_rm2": 53.4825, "r_rtfr": 5833.33, "c_rtfr": 5.0148e-17, "c_cmom": 7.45365e-15}
bad = [k for k, w in want.items() if abs(v.get(k, 0) / w - 1) > 1e-3]
if bad or not 1e-17 < v.get("c_ncap", 0) < 1e-14:
    raise SystemExit(f"[ERROR] passives_ngspice: {v}")
PY
fi

# ---------------------------------------------------------------------------
# Layout: generator, LVS and DRC
# ---------------------------------------------------------------------------
# cell, generator arguments, device call of the schematic (after the nets p
# and n, so rtfr starts with its substrate net)
CELLS="t_rm2|rm -n 2 -w 0.018 -l 1.8|rm2 w=18n l=1.8u
t_rm5|rm -n 5 -w 0.024 -l 2|rm5 w=24n l=2u
t_rm9|rm -n 9 -w 0.12 -l 3|rm9 w=120n l=3u
t_rtfr|rtfr -w 0.108 -l 1|vss rtfr w=108n l=1u
t_cm47|cmom --bot 4 --top 7 -w 1 -l 2|cmom_m4m7 w=1u l=2u
t_cm13|cmom --bot 1 --top 3 -w 0.5 -l 0.5|cmom_m1m3 w=0.5u l=0.5u
t_cm17|cmom --bot 1 --top 7 -w 1.5 -l 1|cmom_m1m7 w=1.5u l=1u"

run_lvs() { # cell, schematic
    klayout -b -r "$LVS" -rd input="$PWD/$1.gds" -rd topcell="$1" -rd schematic="$PWD/$2" \
        -rd report="$PWD/${2%.cdl}.lvsdb" > "${2%.cdl}.lvs.log" 2>&1
    grep -q "netlists match" "${2%.cdl}.lvs.log"
}
drc_rules() { # cell: the violated rules, sorted
    klayout -b -r "$DRC" -rd input="$PWD/$1.gds" -rd topcell="$1" -rd report="$PWD/$1.lyrdb" -rd threads=2 \
        > "$1.drc.log" 2>&1 || { echo "DRC_ERROR"; return; }
    python3 - "$1.lyrdb" <<'PY'
import sys
import klayout.rdb as rdb
r = rdb.ReportDatabase()
r.load(sys.argv[1])
print(" ".join(sorted({r.category_by_id(i.category_id()).name().split()[0] for i in r.each_item()})))
PY
}

if [ -z "$FAILED" ]; then
    while IFS='|' read -r cell args call; do
        # shellcheck disable=SC2086 # $args is a list of options
        python3 "$GEN" $args -o "$cell.gds" --cell "$cell" > "$cell.gen.log" 2>&1 || { FAILED="asap7_layout.py failed for $cell"; break; }
        printf '.subckt %s p n\nX1 p n %s\n.ends\n' "$cell" "$call" > "$cell.cdl"
        run_lvs "$cell" "$cell.cdl" || { FAILED="LVS of $cell does not match"; break; }
        RULES=$(drc_rules "$cell")
        [ -z "$RULES" ] || { FAILED="DRC of $cell reports <$RULES>"; break; }
        [ -n "$DEBUG" ] && echo "[INFO] $cell: LVS matches, DRC clean."
    done <<< "$CELLS"
fi

# Wrong schematic values must not match
if [ -z "$FAILED" ]; then
    while IFS='|' read -r cell call; do
        printf '.subckt %s p n\nX1 p n %s\n.ends\n' "$cell" "$call" > "${cell}_wrong.cdl"
        if run_lvs "$cell" "${cell}_wrong.cdl"; then
            FAILED="LVS matched $cell against <$call>"
            break
        fi
    done <<< "t_rm2|rm2 w=18n l=1.9u
t_rm5|rm4 w=24n l=2u
t_rtfr|vss rtfr w=108n l=1.1u
t_cm47|cmom_m4m7 w=1u l=1.9u
t_cm47|cmom_m4m6 w=1u l=2u"
fi

# Broken layouts: a capacitor finger cut in two (LVS), and one layout per
# passive rule group (DRC)
if [ -z "$FAILED" ]; then
    python3 - <<'PY' || FAILED="could not write the broken layouts"
import klayout.db as db

def edit(src, dst, cell, fn):
    ly = db.Layout()
    ly.read(src)
    fn(ly, ly.cell(cell))
    ly.write(dst)

def nm(v):
    return round(v / 0.25)

def shapes(ly, c, layer, datatype=0):
    return c.shapes(ly.layer(layer, datatype))

def cut_finger(ly, c):
    # split the third M7 finger in the middle: its upper half floats
    s = sorted(shapes(ly, c, 70).each(), key=lambda x: x.box.left)[2]
    b = s.box
    shapes(ly, c, 70).insert(db.Box(b.left, b.bottom, b.right, b.center().y - nm(100)))
    shapes(ly, c, 70).insert(db.Box(b.left, b.center().y + nm(100), b.right, b.top))
    s.delete()

def narrow_tfr(ly, c):
    s = next(shapes(ly, c, 121).each())
    b = s.box
    s.box = db.Box(b.left, b.bottom, b.right, b.bottom + nm(40))

def drop_v0(ly, c):
    next(shapes(ly, c, 18).each()).delete()

def via_on_resistor(ly, c):
    shapes(ly, c, 21).insert(db.Box(nm(500), 0, nm(518), nm(18)))

def wide_finger(ly, c):
    s = sorted(shapes(ly, c, 40).each(), key=lambda x: x.box.bottom)[0]
    b = s.box
    s.box = db.Box(b.left, b.bottom - nm(8), b.right, b.top)

edit("t_cm47.gds", "t_cm47_cut.gds", "t_cm47", cut_finger)
edit("t_rtfr.gds", "t_rtfr_narrow.gds", "t_rtfr", narrow_tfr)
edit("t_rtfr.gds", "t_rtfr_nov0.gds", "t_rtfr", drop_v0)
edit("t_rm2.gds", "t_rm2_via.gds", "t_rm2", via_on_resistor)
edit("t_cm47.gds", "t_cm47_wide.gds", "t_cm47", wide_finger)
PY
fi
if [ -z "$FAILED" ]; then
    klayout -b -r "$LVS" -rd input="$PWD/t_cm47_cut.gds" -rd topcell=t_cm47 -rd schematic="$PWD/t_cm47.cdl" \
        -rd report="$PWD/t_cm47_cut.lvsdb" > t_cm47_cut.lvs.log 2>&1
    grep -q "netlists do not match" t_cm47_cut.lvs.log || FAILED="LVS matched a MOM capacitor with a cut finger"
fi
if [ -z "$FAILED" ]; then
    while IFS='|' read -r gds cell rule; do
        cp "$gds.gds" drc_neg.gds
        python3 -c "
import klayout.db as db
ly = db.Layout(); ly.read('drc_neg.gds'); ly.cell('$cell').name = 'drc_neg'; ly.write('drc_neg.gds')"
        RULES=$(drc_rules drc_neg)
        [ -n "$DEBUG" ] && echo "[INFO] $gds: DRC reports <$RULES>."
        case " $RULES " in
            *" $rule "*) ;;
            *) FAILED="DRC of $gds reports <$RULES>, not $rule"; break ;;
        esac
    done <<< "t_rtfr_narrow|t_rtfr|TFR.W.1
t_rtfr_nov0|t_rtfr|TFR.M1.AUX.1
t_rm2_via|t_rm2|RES.M2.4
t_cm47_wide|t_cm47|MOM.M4.W.2"
fi

# ---------------------------------------------------------------------------
# FinFETs and MOS capacitors: generator, then every PCell
# ---------------------------------------------------------------------------
# cell, generator arguments or "-" for a PCell cell, pins, device line, allowed DRC result
check_cell() {
    printf '.subckt %s %s\n%s\n.ends\n' "$1" "$3" "$4" > "$1.cdl"
    run_lvs "$1" "$1.cdl" || { FAILED="LVS of $1 does not match"; return 1; }
    RULES=$(drc_rules "$1")
    [ "$RULES" = "$5" ] || { FAILED="DRC of $1 reports <$RULES> instead of <$5>"; return 1; }
    [ -n "$DEBUG" ] && echo "[INFO] $1: LVS matches, DRC reports <$RULES>."
    return 0
}

if [ -z "$FAILED" ]; then
    while IFS='|' read -r cell args pins line; do
        # shellcheck disable=SC2086 # $args is a list of options
        python3 "$GEN" mos $args -o "$cell.gds" --cell "$cell" > "$cell.gen.log" 2>&1 || { FAILED="asap7_layout.py failed for $cell"; break; }
        check_cell "$cell" - "$pins" "$line" ACTIVE.LUP.1 || break
    done <<< "t_n1|--type n --nfin 3 --nf 1|D G S|M1 D G S S nmos_rvt l=20n nfin=3
t_p2|--type p --vt lvt --nfin 4 --nf 2 --strap|D G S|X1 D G S S pmos_lvt l=20n nfin=4 m=2
t_n3|--type n --vt sram --nfin 8 --nf 3 --strap|D G S|X1 D G S S nmos_sram l=20n nfin=8 m=3
t_c5|--type n --vt slvt --nfin 1 --nf 5 --cap|G B|X1 B G B B nmos_slvt l=20n nfin=1 m=5
t_l60|--type n --nfin 3 --nf 2 --lg 60 --strap|D G S|X1 D G S S nmos_rvt l=60n nfin=3 m=2
t_l80|--type p --vt lvt --nfin 2 --nf 3 --lg 80 --cap|G B|X1 B G B B pmos_lvt l=80n nfin=2 m=3
t_io|--type n --vt 18 --nfin 4 --nf 2 --strap|D G S|X1 D G S S nmos_18 l=80n nfin=4 m=2
t_iop|--type p --vt 18 --nfin 2 --nf 1 --lg 240|D G S|M1 D G S S pmos_18 l=240n nfin=2"
fi
if [ -z "$FAILED" ]; then
    printf '.subckt t_p2 D G S\nX1 D G S S pmos_lvt l=20n nfin=5 m=2\n.ends\n' > t_p2_wrong.cdl
    run_lvs t_p2 t_p2_wrong.cdl && FAILED="LVS matched a FinFET against the wrong fin count"
fi
if [ -z "$FAILED" ]; then
    # wrong gate length, and a core device where the layout has an IO device
    printf '.subckt t_l60 D G S\nX1 D G S S nmos_rvt l=36n nfin=3 m=2\n.ends\n' > t_l60_wrong.cdl
    run_lvs t_l60 t_l60_wrong.cdl && FAILED="LVS matched a FinFET against the wrong gate length"
    printf '.subckt t_io D G S\nX1 D G S S nmos_rvt l=80n nfin=4 m=2\n.ends\n' > t_io_wrong.cdl
    run_lvs t_io t_io_wrong.cdl && FAILED="LVS matched an IO FinFET against a core FinFET"
fi
if [ -z "$FAILED" ]; then
    # all gates 2 nm longer: 22 nm is not a gate length of the set
    python3 - <<'PY'
import klayout.db as db
ly = db.Layout()
ly.read("t_n1.gds")
c = ly.cell("t_n1")
c.name = "drc_neg"
for s in c.shapes(ly.layer(7, 0)).each():
    b = s.box
    s.box = db.Box(b.left, b.bottom, b.right + 8, b.top)
ly.write("drc_neg.gds")
PY
    RULES=$(drc_rules drc_neg)
    case " $RULES " in
        *" GATE.W.1 "*) ;;
        *) FAILED="DRC of a 22 nm gate reports <$RULES>, not GATE.W.1" ;;
    esac
fi

# PCells: the library is registered by the autorun macro of the technology
# directory (KLAYOUT_PATH is set by sak-pdk-script.sh), -b would skip it
if [ -z "$FAILED" ]; then
    cat > pcells.py <<'PY'
import pya

lib = pya.Library.library_by_name("ASAP7", "asap7")
names = sorted(lib.layout().pcell_names()) if lib else []
print("PCELLS", " ".join(names))
cells = {
    "pc_nmos": ("nmos", dict(vt="lvt", nfin=5, nf=2, strap=True)),
    "pc_pmos": ("pmos", dict(vt="rvt", nfin=2, nf=1, strap=False)),
    "pc_ncap": ("ncap", dict(vt="slvt", nfin=4, nf=3)),
    "pc_pcap": ("pcap", dict(vt="sram", nfin=3, nf=2)),
    "pc_rm": ("rm", dict(n=6, w=0.032, l=2.0)),
    "pc_rtfr": ("rtfr", dict(w=0.2, l=3.0)),
    "pc_cmom": ("cmom", dict(bot=2, top=5, w=1.0, l=0.8)),
    "pc_l36": ("nmos", dict(vt="rvt", l=36, nfin=3, nf=2, strap=True)),
    "pc_io": ("pmos", dict(vt="18", l=160, nfin=3, nf=2, strap=True)),
    "pc_ndio": ("ndio", dict(nfin=3, m=2)),
    "pc_pdio": ("pdio", dict(nfin=4, m=4)),
    "pc_pnp": ("pnp", dict(nfin=4, m=1)),
    "pc_pad": ("pad", dict(w=10.0, l=10.0)),
}
# a FinFET with the tap of its row abutting on the right
taps = {"pc_nmos_tap": ("nmos", "ptap", 5, 2), "pc_pmos_tap": ("pmos", "ntap", 2, 1)}
for name, (pcell, params) in list(cells.items()) + [(n, (v[0], None)) for n, v in taps.items()]:
    ly = pya.Layout()
    ly.technology_name = "asap7"
    ly.dbu = 0.00025
    top = ly.create_cell(name)
    if params is None:
        _, tap, nfin, nf = taps[name]
        params = dict(vt="rvt", nfin=nfin, nf=nf, strap=True)
        tap_cell = ly.create_cell(tap, "ASAP7", dict(nfin=nfin))
        top.insert(pya.CellInstArray(tap_cell.cell_index(), pya.Trans(round(0.054 * (nf + 2) / ly.dbu), 0)))
    top.insert(pya.CellInstArray(ly.create_cell(pcell, "ASAP7", params).cell_index(), pya.Trans()))
    top.flatten(True)
    ly.write(name + ".gds")
PY
    klayout -zz -r pcells.py > pcells.log 2>&1 || FAILED="KLayout failed to create the PCell cells"
    PCELLS=$(sed -n 's/^PCELLS //p' pcells.log)
    [ -n "$FAILED" ] || [ "$PCELLS" = "cmom ncap ndio nmos ntap pad pcap pdio pmos pnp ptap rm rtfr" ] || FAILED="the library ASAP7 has the PCells <$PCELLS>"
fi
if [ -z "$FAILED" ]; then
    while IFS='|' read -r cell pins line rules; do
        check_cell "$cell" - "$pins" "$line" "$rules" || break
    done <<< "pc_nmos|D G S|X1 D G S S nmos_lvt l=20n nfin=5 m=2|ACTIVE.LUP.1
pc_pmos|D G S|X1 D G S S pmos_rvt l=20n nfin=2|ACTIVE.LUP.1
pc_ncap|G B|X1 B G B B nmos_slvt l=20n nfin=4 m=3|ACTIVE.LUP.1
pc_pcap|G B|X1 B G B B pmos_sram l=20n nfin=3 m=2|ACTIVE.LUP.1
pc_rm|p n|X1 p n rm6 w=32n l=2u|
pc_rtfr|p n|X1 p n vss rtfr w=200n l=3u|
pc_cmom|p n|X1 p n cmom_m2m5 w=1u l=0.8u|
pc_nmos_tap|D G S B|X1 D G S B nmos_rvt l=20n nfin=5 m=2|
pc_pmos_tap|D G S B|X1 D G S B pmos_rvt l=20n nfin=2|
pc_l36|D G S|X1 D G S S nmos_rvt l=36n nfin=3 m=2|ACTIVE.LUP.1
pc_io|D G S|X1 D G S S pmos_18 l=160n nfin=3 m=2|ACTIVE.LUP.1
pc_ndio|a k|X1 a k ndio nfin=3 m=2|
pc_pdio|a k|X1 a k pdio nfin=4 m=4|
pc_pnp|c b e|X1 c b e pnp nfin=4 m=1|"
    [ -n "$FAILED" ] || [ -z "$(drc_rules pc_pad)" ] || FAILED="DRC of the pad PCell is not clean"
fi

# Body: with -rd body=true the body of the FinFET is the net of its tap
run_lvs_body() { # cell, schematic
    klayout -b -r "$LVS" -rd input="$PWD/$1.gds" -rd topcell="$1" -rd schematic="$PWD/$2" -rd body=true \
        -rd report="$PWD/${2%.cdl}.lvsdb" > "${2%.cdl}.lvs.log" 2>&1
    grep -q "netlists match" "${2%.cdl}.lvs.log"
}
if [ -z "$FAILED" ]; then
    printf '.subckt pc_nmos_tap D G S B\nX1 D G S B nmos_rvt l=20n nfin=5 m=2\n.ends\n' > body_ok.cdl
    printf '.subckt pc_nmos_tap D G S B\nX1 D G S S nmos_rvt l=20n nfin=5 m=2\n.ends\n' > body_wrong.cdl
    printf '.subckt pc_pmos_tap D G S B\nX1 D G S B pmos_rvt l=20n nfin=2\n.ends\n' > body_p.cdl
    run_lvs_body pc_nmos_tap body_ok.cdl || FAILED="LVS with body=true does not match an NMOS with its tap"
    [ -n "$FAILED" ] || run_lvs_body pc_pmos_tap body_p.cdl || FAILED="LVS with body=true does not match a PMOS with its tap"
    [ -n "$FAILED" ] || { run_lvs_body pc_nmos_tap body_wrong.cdl && FAILED="LVS with body=true matched a body tied to the source"; }
fi

# Parasitic capacitances: rm2 between two M2 wires of 10 um at minimum spacing
if [ -z "$FAILED" ]; then
    python3 - <<'PY'
import klayout.db as db
ly = db.Layout()
ly.dbu = 0.00025
c = ly.create_cell("wires")
def box(layer, x1, y1, x2, y2, datatype=0):
    c.shapes(ly.layer(layer, datatype)).insert(db.DBox(x1, y1, x2, y2))
box(20, 0, 0, 10, 0.018)
box(20, 0, 0.036, 10, 0.054)
box(20, 10, 0, 10.018, 0.054)
box(120, 10, 0.018, 10.018, 0.036, 2)
c.shapes(ly.layer(20, 251)).insert(db.DText("d", 0.1, 0.009))
c.shapes(ly.layer(20, 251)).insert(db.DText("e", 0.1, 0.045))
ly.write("wires.gds")
PY
    printf '.subckt wires d e\nX1 d e rm2 w=18n l=18n\n.ends\n' > wires.cdl
    klayout -b -r "$LVS" -rd input="$PWD/wires.gds" -rd topcell=wires -rd schematic="$PWD/wires.cdl" \
        -rd report="$PWD/wires.lvsdb" -rd pex="$PWD/wires.pex.spice" > wires.lvs.log 2>&1
    grep -q "netlists match" wires.lvs.log || FAILED="LVS with pex= does not match"
fi
if [ -z "$FAILED" ]; then
    python3 - "$PAR" <<'PY' || FAILED="the wire capacitances of wires.pex.spice are off"
import json
import re
import sys
m = json.load(open(sys.argv[1]))["metals"]["2"]
caps = {tuple(sorted((a, b))): float(c) for a, b, c in re.findall(r"^Cp\d+ (\S+) (\S+) (\S+)", open("wires.pex.spice").read(), re.M)}
want = {("d", "e"): m["cc"] * 10e-15, ("VSUB", "d"): m["cg0"] * 10e-15, ("VSUB", "e"): m["cg0"] * 10e-15}
bad = [k for k, w in want.items() if abs(caps.get(k, 0) / w - 1) > 0.02]
if bad or len(caps) != 3:
    raise SystemExit(f"[ERROR] {caps}, expected {want}")
PY
fi
if [ -z "$FAILED" ]; then
    # the extracted netlist is a low-pass in ngspice: 1 V DC through rm2 of 0.53 Ohm
    {
        echo "* extracted netlist"
        echo ".lib $LIBS/ngspice/models/asap7.lib tt"
        echo ".include wires.pex.spice"
        echo "v1 d 0 dc 1 ac 1"
        echo "x1 d e 0 wires"
        echo "r1 e 0 1k"
        echo ".control"
        echo "op"
        echo "print v(e)"
        echo ".endc"
        echo ".end"
    } > wires_tb.sp
    ngspice -b wires_tb.sp > wires_tb.log 2>&1
    grep -q "^v(e) = 9.99" wires_tb.log || FAILED="the extracted netlist does not simulate"
fi
if [ -z "$FAILED" ]; then
    # wire resistance: each wire is 9.9 um of 18 nm M2 from its label to the resistor
    klayout -b -r "$LVS" -rd input="$PWD/wires.gds" -rd topcell=wires -rd schematic="$PWD/wires.cdl" \
        -rd report="$PWD/wires_r.lvsdb" -rd pex="$PWD/wires_r.pex.spice" -rd pex_res=true > wires_r.lvs.log 2>&1
    python3 - "$PAR" <<'PY' || FAILED="the wire resistances of wires_r.pex.spice are off"
import json
import re
import sys
rsh = json.load(open(sys.argv[1]))["metals"]["2"]["rsh"]
r = [float(x) for x in re.findall(r"^Rw\d+ \S+ \S+ (\S+)", open("wires_r.pex.spice").read(), re.M)]
want = rsh * 9.9 / 0.018
if len(r) != 2 or any(abs(x / want - 1) > 0.02 for x in r):
    raise SystemExit(f"[ERROR] wire resistances {r}, expected two of {want:.1f} Ohm")
PY
fi

# Pad: plate over M9 stripes, the first stripe continues as rm9 to the pin n
if [ -z "$FAILED" ]; then
    python3 "$GEN" pad -w 20 -l 20 -o t_pad.gds --cell t_pad > t_pad.gen.log 2>&1 || FAILED="asap7_layout.py failed for the pad"
    python3 - <<'PY'
import klayout.db as db
ly = db.Layout()
ly.read("t_pad.gds")
c = ly.cell("t_pad")
c.shapes(ly.layer(90, 0)).insert(db.DBox(1.0, 19.5, 2.0, 24.0))
c.shapes(ly.layer(120, 9)).insert(db.DBox(1.0, 21.0, 2.0, 22.0))
c.shapes(ly.layer(90, 251)).insert(db.DText("n", 1.5, 23.5))
ly.write("t_pad.gds")
PY
    printf '.subckt t_pad pad n\nX1 pad n rm9 w=1u l=1u\n.ends\n' > t_pad.cdl
    klayout -b -r "$LVS" -rd input="$PWD/t_pad.gds" -rd topcell=t_pad -rd schematic="$PWD/t_pad.cdl" \
        -rd report="$PWD/t_pad.lvsdb" -rd pex="$PWD/t_pad.pex.spice" > t_pad.lvs.log 2>&1
    grep -q "netlists match" t_pad.lvs.log || FAILED="LVS of the pad does not match"
    RULES=$(drc_rules t_pad)
    [ -n "$FAILED" ] || [ -z "$RULES" ] || FAILED="DRC of the pad reports <$RULES>"
    # 400 um^2 of pad plate give more than 10 fF to the substrate
    [ -n "$FAILED" ] || awk '/^Cp[0-9]+ VSUB pad /{ok = ($4 > 1e-14 && $4 < 3e-14)} END{exit !ok}' t_pad.pex.spice ||
        FAILED="the pad capacitance in t_pad.pex.spice is off"
fi

# ---------------------------------------------------------------------------
# Junction diodes and the vertical PNP
# ---------------------------------------------------------------------------
if [ -z "$FAILED" ]; then
    for temp in 27 127; do
        {
            echo "* ASAP7 junction devices"
            echo ".lib $LIBS/ngspice/models/asap7.lib tt"
            echo ".temp $temp"
            i=0
            for d in "a1 0 ndio nfin=4 m=10" "a2 0 pdio nfin=4 m=10" "0 0 a3 pnp nfin=4 m=1" "0 0 a4 pnp nfin=4 m=8"; do
                i=$((i + 1))
                echo "i$i 0 a$i 1n"
                echo "x$i $d"
            done
            echo ".control"
            echo "op"
            echo "print v(a1) v(a2) v(a3) v(a4)"
            echo ".endc"
            echo ".end"
        } > "ng_j$temp.sp"
        ngspice -b "ng_j$temp.sp" > "ng_j$temp.log" 2>&1 || FAILED="ngspice failed (junction devices)"
    done
    {
        echo "* ASAP7 junction devices"
        echo ".lib $LIBS/xyce/models/asap7.lib tt"
        echo ".options device temp=27"
        i=0
        for d in "a1 0 ndio nfin=4 m=10" "a2 0 pdio nfin=4 m=10" "0 0 a3 pnp nfin=4 m=1" "0 0 a4 pnp nfin=4 m=8"; do
            i=$((i + 1))
            echo "i$i 0 a$i 1n"
            echo "x$i $d"
        done
        echo ".dc i1 1n 1n 1n"
        echo ".print dc format=noindex file=xy_j.txt v(a1) v(a2) v(a3) v(a4)"
        echo ".end"
    } > xy_j.cir
    Xyce xy_j.cir > xy_j.log 2>&1 || FAILED="Xyce failed (junction devices)"
    {
        echo "ASAP7 junction devices"
        echo "ground 0"
        echo "include \"asap7.lib\" section=tt"
        echo "model isource isource"
        i=0
        for d in "(a1 0) ndio nfin=4 m=10" "(a2 0) pdio nfin=4 m=10" "(0 0 a3) pnp nfin=4 m=1" "(0 0 a4) pnp nfin=4 m=8"; do
            i=$((i + 1))
            echo "i$i (0 a$i) isource dc=1n"
            echo "x$i $d"
        done
        echo "control"
        echo "  options temp=27"
        echo "  analysis vc_j op"
        echo "endc"
    } > vc_j.sim
    vacask vc_j.sim > vc_j.log 2>&1 || FAILED="VACASK failed (junction devices)"
fi
if [ -z "$FAILED" ]; then
    python3 - "$PAR" <<'PY' > j.check.log 2>&1 || FAILED="junction device voltages off (see j.check.log)"
import json
import math
import re
import sys
import numpy as np
try:
    from vacask.rawfile import rawread
except ImportError:
    from rawfile import rawread

n = json.load(open(sys.argv[1]))["junction"]["n"]
def ng(temp):
    return [float(x) for x in re.findall(r"^v\(a\d\) = (\S+)", open(f"ng_j{temp}.log").read(), re.M)]
v = {"ngspice": ng(27)}
rows = [l for l in open("xy_j.txt") if re.match(r"\s*[-+0-9]", l)]
v["xyce"] = [float(x) for x in rows[0].split()]
r = rawread("vc_j.raw").get()
v["vacask"] = [float(np.ravel(r[f"a{i}"])[0]) for i in range(1, 5)]
bad = []
for sim, x in v.items():
    print(sim, [round(y, 4) for y in x])
    if len(x) != 4 or any(abs(a - b) > 1e-3 for a, b in zip(x, v["ngspice"])):
        bad.append(f"{sim} differs from ngspice by more than 1 mV")
    if not all(0.6 < y < 0.9 for y in x):
        bad.append(f"{sim}: forward voltages outside 0.6 V to 0.9 V")
hot = ng(127)
tc = (hot[0] - v["ngspice"][0]) / 100 * 1e3
print(f"temperature coefficient of ndio: {tc:.2f} mV/K")
if not -2.5 < tc < -1.0:
    bad.append(f"temperature coefficient of ndio is {tc:.2f} mV/K")
want = n * 1.380649e-23 * 300.15 / 1.602176634e-19 * math.log(8)
got = v["ngspice"][2] - v["ngspice"][3]
print(f"VEB of 1 strip minus 8 strips: {got * 1e3:.2f} mV, expected {want * 1e3:.2f} mV")
if abs(got / want - 1) > 0.02:
    bad.append(f"delta VEB is {got * 1e3:.2f} mV instead of {want * 1e3:.2f} mV")
for b in bad:
    print("[ERROR]", b)
raise SystemExit(1 if bad else 0)
PY
    [ -n "$DEBUG" ] && cat j.check.log
fi
if [ -z "$FAILED" ]; then
    while IFS='|' read -r cell args pins line; do
        # shellcheck disable=SC2086 # $args is a list of options
        python3 "$GEN" $args -o "$cell.gds" --cell "$cell" > "$cell.gen.log" 2>&1 || { FAILED="asap7_layout.py failed for $cell"; break; }
        check_cell "$cell" - "$pins" "$line" "" || break
    done <<< "t_ndio|ndio --nfin 4 -m 3|a k|X1 a k ndio nfin=4 m=3
t_pdio|pdio --nfin 2 -m 1|a k|X1 a k pdio nfin=2 m=1
t_pnp|pnp --nfin 4 -m 2|c b e|X1 c b e pnp nfin=4 m=2"
fi
if [ -z "$FAILED" ]; then
    printf '.subckt t_pnp c b e\nX1 c e b pnp nfin=4 m=2\n.ends\n' > t_pnp_swap.cdl
    printf '.subckt t_pnp c b e\nX1 c b e pnp nfin=4 m=3\n.ends\n' > t_pnp_area.cdl
    printf '.subckt t_ndio a k\nX1 a k pdio nfin=4 m=3\n.ends\n' > t_ndio_type.cdl
    run_lvs t_pnp t_pnp_swap.cdl && FAILED="LVS matched a PNP with base and emitter swapped"
    run_lvs t_pnp t_pnp_area.cdl && FAILED="LVS matched a PNP against the wrong area"
    run_lvs t_ndio t_ndio_type.cdl && FAILED="LVS matched ndio against pdio"
fi

# Routed example
if [ -z "$FAILED" ]; then
    python3 "$LIBS/klayout/python/asap7_example.py" . > cs_amp.gen.log 2>&1 || FAILED="asap7_example.py failed"
fi
if [ -z "$FAILED" ]; then
    klayout -b -r "$LVS" -rd input="$PWD/cs_amp.gds" -rd topcell=cs_amp -rd schematic="$PWD/cs_amp.cdl" -rd body=true \
        -rd report="$PWD/cs_amp.lvsdb" -rd pex="$PWD/cs_amp.pex.spice" > cs_amp.lvs.log 2>&1
    grep -q "netlists match" cs_amp.lvs.log || FAILED="LVS of the example cs_amp does not match"
    RULES=$(drc_rules cs_amp)
    [ -n "$FAILED" ] || [ -z "$RULES" ] || FAILED="DRC of the example cs_amp reports <$RULES>"
fi
if [ -z "$FAILED" ]; then
    # 5.83 kOhm load: the output sits between the rails at VGS = 0.45 V with a gain above 1
    {
        echo "* extracted cs_amp"
        echo ".lib $LIBS/ngspice/models/asap7.lib tt"
        echo ".include cs_amp.pex.spice"
        echo "vdd vdd 0 0.7"
        echo "vin in 0 dc 0.45 ac 1"
        echo "x1 in out vdd 0 0 cs_amp"
        echo ".control"
        echo "op"
        echo "print v(out)"
        echo "ac dec 1 1k 1k"
        echo "print vdb(out) vp(out)"
        echo ".endc"
        echo ".end"
    } > cs_amp_tb.sp
    ngspice -b cs_amp_tb.sp > cs_amp_tb.log 2>&1
    python3 - <<'PY' || FAILED="the extracted example cs_amp does not amplify"
import re
t = open("cs_amp_tb.log").read()
vout = float(re.search(r"^v\(out\) = (\S+)", t, re.M).group(1))
gain = float(re.search(r"^vdb\(out\) = (\S+)", t, re.M).group(1))
if not (0.1 < vout < 0.65 and gain > 0):
    raise SystemExit(f"[ERROR] cs_amp: v(out) = {vout} V, gain = {gain} dB")
PY
fi
if [ -z "$FAILED" ]; then
    # the same with wire resistance: the gain stays within 1 dB
    klayout -b -r "$LVS" -rd input="$PWD/cs_amp.gds" -rd topcell=cs_amp -rd schematic="$PWD/cs_amp.cdl" -rd body=true \
        -rd report="$PWD/cs_amp_r.lvsdb" -rd pex="$PWD/cs_amp_r.pex.spice" -rd pex_res=true > cs_amp_r.lvs.log 2>&1
    sed 's/cs_amp.pex.spice/cs_amp_r.pex.spice/' cs_amp_tb.sp > cs_amp_r_tb.sp
    ngspice -b cs_amp_r_tb.sp > cs_amp_r_tb.log 2>&1
    python3 - <<'PY' || FAILED="the example cs_amp with wire resistance is off"
import re
g = [float(re.search(r"^vdb\(out\) = (\S+)", open(f).read(), re.M).group(1)) for f in ("cs_amp_tb.log", "cs_amp_r_tb.log")]
n = len(re.findall(r"^Rw\d+ ", open("cs_amp_r.pex.spice").read(), re.M))
if n < 5 or abs(g[0] - g[1]) > 1:
    raise SystemExit(f"[ERROR] cs_amp: {n} wire resistors, gain {g[0]} dB without and {g[1]} dB with them")
PY
fi

if [ -n "$FAILED" ]; then
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED). Check the logs in <$WORKDIR>."
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
