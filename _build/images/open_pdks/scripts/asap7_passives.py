#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Passive devices for ASAP7: metal resistors, MOM capacitor, thin-film resistor.

ASAP7 r1p7 defines FinFETs only. The devices here are an IIC-OSIC-TOOLS
addition for analog design. They are not part of ASAP7.

* rm1 ... rm9: metal resistor, a wire segment under the marker RES_M<n>.
  Sheet resistance is the wire resistance per length of the OpenRCX rules of
  OpenROAD-flow-scripts (rcx_patterns.rules) times the minimum width, so a
  resistor reads what the digital flow extracts for the same wire.
* cmom_m<bot>m<top>: woven metal-oxide-metal capacitor on M<bot> to M<top>
  (M1 to M7), minimum-width fingers at minimum spacing in the preferred
  direction of each layer, alternately on the two plates. The capacitance
  per finger pair and length is the coupling of the same OpenRCX rules.
* rtfr: TiN thin-film resistor in the dielectric below M1, contacted by V0.
  ASAP7 has no such layer, the layer, its design rules and its parameters
  are assumptions (see TFR below).

asap7_models.py calls this module for the simulator libraries and writes the
parameters as JSON for the KLayout LVS and DRC decks and the layout generator,
so all of them use one set of numbers.
"""

import json
import math
import re
import sys

# Layer number, finger direction (H: along x), minimum width and spacing in um
# (ASAP7 DRM, tech LEF of ORFS)
METALS = {
    1: (19, "V", 0.018, 0.018),
    2: (20, "H", 0.018, 0.018),
    3: (30, "V", 0.018, 0.018),
    4: (40, "H", 0.024, 0.024),
    5: (50, "V", 0.024, 0.024),
    6: (60, "H", 0.032, 0.032),
    7: (70, "V", 0.032, 0.032),
    8: (80, "H", 0.040, 0.040),
    9: (90, "V", 0.040, 0.040),
}

# Gate lengths of the FinFETs in nm. ASAP7 draws every gate at 20 nm on a
# 54 nm pitch, and its BSIM-CMG cards are fitted at that length only. The
# model scales with length, so longer gates are an extrapolation.
#
# No gate-length list of a 7 nm process is published. The set is a guess from
# two Intel papers, scaled to the 54 nm gate pitch of ASAP7:
# * 24 and 28 nm: the 22 nm SoC process offers logic gates of 30, 34 and
#   40 nm, 13 % and 33 % above the shortest (Jan et al., IEDM 2012, table 1).
# * 36, 60 and 80 nm: 22FFL offers long-channel analog FinFETs of 74, 120 and
#   160 nm on gate pitches of 144, 216 and 270 nm, next to logic on a 108 nm
#   pitch (Sell et al., IEDM 2017, as reported by Real World Tech and
#   WikiChip). Half of these lengths for half the logic gate pitch.
# The gate spacing stays the one of ASAP7 (54 nm pitch minus 20 nm) for all
# lengths, which is tighter than the 22FFL pitches scaled the same way.
MOS_LENGTHS = [20, 24, 28, 36, 60, 80]
MOS_GATE_SPACE = 34
# 1.8 V IO FinFETs (asap7_models.py). 80 nm on a 180 nm gate pitch is the
# minimum of the 1.8 V transistors of the Intel 22 nm SoC process (Jan et al.,
# IEDM 2012, table 1). 160 nm is the longest 22FFL gate. 240 nm stays below
# the longest published FinFET gate found, the 280 nm minimum of the 3.3 V
# transistors of the same 22 nm process. Longer gates are left out: the
# maximum gate length of a FinFET process is limited by gate patterning and
# metal-gate integration (Loke et al., "Analog/mixed-signal design in FinFET
# technologies"), and stacking is used beyond it.
IO_LENGTHS = [80, 160, 240]
IO_GATE_SPACE = 100

# New layers, none of them is used by ASAP7 or ORFS
RES_MARKER_LAYER = 120  # datatype is the metal level, 1 to 9
TFR_LAYER = (121, 0)
MOMCAP_LAYER = (122, 0)
TG_LAYER = (123, 0)     # thick gate oxide of the IO FinFETs
DIODE_LAYER = (124, 0)  # marker of the junction diodes ndio and pdio
BJT_LAYER = (125, 0)    # marker of the vertical PNP

# Junction devices, an IIC-OSIC-TOOLS addition: ASAP7 has no diode and no
# bipolar transistor. They are the contacted active area of a tap cell with
# the implant of a source or drain: ndio is n+ in the substrate, pdio p+ in
# the well, and pnp the same p+ (emitter) with the well as base and the
# substrate as collector, the parasitic device FinFET bandgap references use.
# The area is the drawn active area, 16 nm by nfin fin pitches per strip.
#
# All parameters are assumed, no data of a 7 nm junction was found:
#   js   1e-19 A/um^2, which puts the forward voltage at 0.78 V for 1 uA/um^2
#   n    1.03, slightly above ideal
#   rs   5 Ohm um^2
#   cj   2 fF/um^2 at zero bias, grading 0.4, built-in potential 0.8 V
#   bf   1.5: the vertical PNP of a FinFET process has a current gain near 1
JUNCTION = {
    "strip": 0.016,     # um, width of one active strip
    "js": 1e-19,        # A/um^2
    "n": 1.03,
    "rs": 5.0,          # Ohm um^2
    "cj": 2e-15,        # F/um^2
    "mj": 0.4,
    "vj": 0.8,
    "bf": 1.5,
    "br": 0.05,
}

MOM_LAYERS = range(1, 8)
# Fingers stay this far (um) inside the MOMCAP marker across their direction,
# so the fingers of the next layer enclose the vias at the marker edge
MOM_EDGE = 0.010

# Copper wires. The temperature coefficient follows Matthiessen's rule: the
# size-effect part of the resistivity does not depend on temperature, so
# TC1 = TC1_bulk * rho_bulk / rho_wire. With bulk copper at 1.68 uOhm cm and
# 3.9e-3/K, and 2.0 to 2.7 uOhm cm for the wires here (sheet resistance times
# a thickness of twice the width, the 2:1 aspect ratio of the ASAP7 paper),
# TC1 is 2.4e-3/K to 3.3e-3/K. One value is used for all layers. TC2 is 0:
# the resistivity of copper is linear in temperature from 290 K to 425 K
# (Schuster, Vangel, Schafft, Microelectronics Reliability 41, 2001).
RM_TC1 = 3.0e-3
RM_TC2 = 0.0

# Thin-film resistor. Assumed, after published TiN resistors: foundry 16 nm and
# 7 nm FinFET processes list a TiN high-resistance resistor, placed in the
# dielectric above the gates and contacted by vias. Thin TiN films are
# reported with 420 Ohm/sq at 50 nm (sputtered) and 550 Ohm/sq with
# -650 ppm/K (bilayer, US20040241951A1), thicker films with +540 ppm/K to
# +750 ppm/K, so a thin film is taken as weakly negative.
#
# Capacitance to the substrate: the film lies about 180 nm of SiO2 above the
# silicon (shallow trench isolation plus the pre-metal dielectric up to the
# level of V0), which gives eps/h = 0.19 fF/um^2. The fringe of both long
# edges is about 2 * eps (Sakurai and Tamaru, IEEE TED 30, 1983, for a width
# near the height), so 0.036 fF/um per edge. Half of the capacitance is put
# on each end.
#
# Mismatch: sigma(dR/R) = ar / sqrt(w * l), the area law of Pelgrom. No value
# for a TiN film was found. Polysilicon resistors are quoted with about
# 3 % um (180 nm CMOS), a film without grain-boundary conduction is taken
# as somewhat better.
TFR = {
    "rsh": 600.0,        # Ohm/sq
    "rend": 15.0,        # Ohm um, resistance of one contacted end times width
    "tc1": -300e-6,      # 1/K
    "tc2": 0.5e-6,       # 1/K^2
    "ca": 0.19,          # fF/um^2 to the substrate
    "cp": 0.036,         # fF/um of edge to the substrate
    "ar": 2.0,           # % um, mismatch of one resistor
    "wmin": 0.054,       # um
    "lmin": 0.108,       # um
}

# Parasitic capacitance of wires (-rd pex= of the LVS deck). Between wires of
# one layer and to the substrate the OpenRCX rules are used. For wide wires
# and between two layers a parallel plate is added, which needs the layer
# stack. ASAP7 publishes none, so it is assumed: a metal is twice as thick
# as its minimum width (the 2:1 aspect ratio of the ASAP7 paper), the
# dielectric to the next metal is as thick as the metal, M1 starts 150 nm
# above the substrate, and the dielectric has a relative permittivity of 2.7,
# the value that reproduces the M1 coupling of the OpenRCX rules.
PEX_M1_HEIGHT = 0.150
PEX_EPS_R = 2.7

# Corner factors on resistance and capacitance. Assumed: no data exists.
CORNERS = {
    "tt": {"rm": 1.00, "cmom": 1.00, "rtfr": 1.00, "ctfr": 1.00, "js": 1.0},
    "ff": {"rm": 0.85, "cmom": 0.90, "rtfr": 0.85, "ctfr": 0.90, "js": 2.0},
    "ss": {"rm": 1.15, "cmom": 1.10, "rtfr": 1.15, "ctfr": 1.10, "js": 0.5},
}

TNOM = 27


def parse_rcx(path):
    """Read wire resistance and coupling per um from the OpenRCX rules.

    Returns {level: (ohm_per_um, farad_per_um)}. The tables are per nm of
    wire, in Ohm and fF. "Metal <n> OVER 0" is a wire over the substrate with a
    neighbor at the listed distance on both sides, so half of its coupling
    belongs to one pair of wires. The value at the minimum spacing is taken.
    """
    text = open(path).read()
    out = {}
    for n, (_, _, width, space) in METALS.items():
        m = re.search(rf"^Metal {n} RESOVER 0\nDIST count \d+ width (\S+)\n(\S+) (\S+) (\S+) (\S+)\n", text, re.M)
        if not m or abs(float(m.group(1)) - width) > 1e-9:
            sys.exit(f"[ERROR] {path}: no resistance table for M{n} at width {width} um")
        r_um = float(m.group(5)) * 1e3
        m = re.search(rf"^Metal {n} OVER 0\nDIST count \d+ width (\S+)\n(.*?)^END DIST", text, re.M | re.S)
        if not m or abs(float(m.group(1)) - width) > 1e-9:
            sys.exit(f"[ERROR] {path}: no coupling table for M{n} at width {width} um")
        rows = [[float(x) for x in line.split()] for line in m.group(2).splitlines()]
        lower = [r for r in rows if r[0] <= space + 1e-9]
        upper = [r for r in rows if r[0] >= space - 1e-9]
        if not lower or not upper:
            sys.exit(f"[ERROR] {path}: no coupling of M{n} at spacing {space} um")
        (d0, c0), (d1, c1) = lower[-1][:2], upper[0][:2]
        # The M6 and M7 tables have no row at 32 nm: interpolate in 1/distance
        coupling = c0 if d0 == d1 else c0 + (c1 - c0) * (1 / space - 1 / d0) / (1 / d1 - 1 / d0)
        # coupling per pair of wires in fF/um over the distance in um, and the
        # capacitance to the substrate of a wire without neighbors
        table = [[r[0], float(f"{r[1] * 1e3 / 2:.6g}")] for r in rows if r[1] > 0]
        alone = [r[2] for r in rows if r[1] == 0]
        if not alone:
            sys.exit(f"[ERROR] {path}: no M{n} row without coupling")
        out[n] = (r_um, coupling * 1e3 * 1e-15 / 2, table, float(f"{alone[0] * 1e3:.6g}"))
    return out


def parse_via_resistance(path):
    """Resistance in Ohm of one via V1 to V9 from setRC.tcl of ORFS (given in kOhm)."""
    text = open(path).read()
    out = {}
    for n in range(1, 10):
        m = re.search(rf"^set_layer_rc -via V{n} -resistance (\S+)", text, re.M)
        if not m:
            sys.exit(f"[ERROR] {path}: no resistance of V{n}")
        out[n] = float(m.group(1)) * 1e3
    return out


def parameters(rcx_path):
    """All numbers the decks, the generator and the models share (tt corner).

    setRC.tcl is read from the directory of the OpenRCX rules.
    """
    rcx = parse_rcx(rcx_path)
    via_r = parse_via_resistance(str(rcx_path).replace("rcx_patterns.rules", "setRC.tcl"))
    # Resistance times area of a via in Ohm um^2 for the wire resistance of
    # -rd pex_res=true: the resistance of one minimum via, whose sides are the
    # minimum widths of the two metals. V<n> is the via above M<n>. V0 has no
    # value in the ORFS files, the one of V1 is taken.
    via_ra = {str(n): float(f"{via_r[n] * METALS[n][2] * METALS[min(n + 1, 9)][2]:.6g}") for n in range(1, 9)}
    via_ra["0"] = via_ra["1"]
    metals = {}
    height = PEX_M1_HEIGHT
    for n, (layer, direction, width, space) in METALS.items():
        r_um, cc, table, alone = rcx[n]
        thickness = 2 * width
        metals[str(n)] = {
            "cc_table": table,
            "cg0": alone,                       # fF/um to the substrate, no neighbors
            "t": thickness,                     # um
            "h": float(f"{height:.4g}"),        # um from the substrate to the bottom
            "layer": layer,
            "dir": direction,
            "wmin": width,
            "smin": space,
            "rsh": round(r_um * width, 6),      # Ohm/sq
            "cc": float(f"{cc * 1e15:.6g}"),    # fF per um of one finger pair
        }
        height += 2 * thickness
    return {
        "metals": metals,
        "res_marker_layer": RES_MARKER_LAYER,
        "tfr_layer": list(TFR_LAYER),
        "momcap_layer": list(MOMCAP_LAYER),
        "mom_layers": [MOM_LAYERS[0], MOM_LAYERS[-1]],
        "mom_edge": MOM_EDGE,
        "rm": {"tc1": RM_TC1, "tc2": RM_TC2},
        "tfr": TFR,
        "pex_eps_r": PEX_EPS_R,
        "via_ra": via_ra,
        "corners": CORNERS,
        "mos_lengths": MOS_LENGTHS,
        "mos_gate_space": MOS_GATE_SPACE,
        "io_lengths": IO_LENGTHS,
        "io_gate_space": IO_GATE_SPACE,
        "tg_layer": list(TG_LAYER),
        "diode_layer": list(DIODE_LAYER),
        "bjt_layer": list(BJT_LAYER),
        "junction": JUNCTION,
        "fin_pitch": 0.027,
        "tnom": TNOM,
    }


def mom_fingers(par, n, w_um, l_um):
    """Finger count and finger length in um of level n in a w x l capacitor.

    The count is even, so the first and the last finger are on different
    plates and each plate is reached from one side.
    """
    m = par["metals"][str(n)]
    pitch = m["wmin"] + m["smin"]
    across, along = (l_um, w_um) if m["dir"] == "H" else (w_um, l_um)
    nf = 2 * math.floor((across - 2 * par["mom_edge"] + m["smin"] + 1e-9) / (2 * pitch))
    return nf, along


def mom_cap(par, bot, top, w_um, l_um):
    """Capacitance in F of cmom_m<bot>m<top> with the footprint w x l."""
    c = 0.0
    for n in range(bot, top + 1):
        nf, along = mom_fingers(par, n, w_um, l_um)
        c += par["metals"][str(n)]["cc"] * 1e-15 * along * max(nf - 1, 0)
    return c


def mom_combinations():
    return [(b, t) for b in MOM_LAYERS for t in MOM_LAYERS if t > b]


def _mom_expr(par, bot, top, scale):
    """Capacitance expression in w and l (m), same in all three simulators."""
    terms = []
    for n in range(bot, top + 1):
        m = par["metals"][str(n)]
        pitch = m["wmin"] + m["smin"]
        across, along = ("l", "w") if m["dir"] == "H" else ("w", "l")
        nf = f"2*floor(({across}*1e6{m['smin'] - 2 * par['mom_edge']:+g}+1e-9)/{2 * pitch:g})"
        terms.append(f"{m['cc'] * scale * 1e-9:g}*{along}*max({nf}-1,0)")
    return "+".join(terms)


HEADER = """{c}
{c} Passive devices, an IIC-OSIC-TOOLS addition: ASAP7 defines no passives.
{c} Generated by asap7_passives.py, see the PDK README for the assumptions.
{c}   rm1 ... rm9 (p n): metal resistor, w l in m, R = rsh*l/w,
{c}     TC1 = {tc1:g}/K
{c}   rtfr (p n b): TiN thin-film resistor (assumed device), w l in m,
{c}     R = ({rsh:g}*l + 2*{rend:g}e-6)/w Ohm, TC1 = {ttc1:g}/K, TC2 = {ttc2:g}/K^2,
{c}     b is the substrate: {ca:g} fF/um^2 and {cp:g} fF/um of edge, half on
{c}     each end. mm=1 adds mismatch, sigma(dR/R) = {ar:g} % um / sqrt(w*l*m)
{c}   cmom_m<bot>m<top> (p n): woven MOM capacitor on M<bot> to M<top>,
{c}     bot 1 to 6, top bot+1 to 7, footprint w (x) and l (y) in m
{c}   ndio (a k), pdio (a k): junction diodes (assumed devices), n+ in the
{c}     substrate and p+ in the well, nfin fins per strip and m strips
{c}   pnp (c b e): vertical PNP (assumed device), emitter p+ in the well,
{c}     base the well, collector the substrate, nfin and m as the diodes
{c} All take the multiplier m. Resistances are given at {tnom} C."""


def header(par, comment):
    t = par["tfr"]
    return HEADER.format(c=comment, tc1=par["rm"]["tc1"], rsh=t["rsh"], rend=t["rend"], ttc1=t["tc1"],
                         ttc2=t["tc2"], ca=t["ca"], cp=t["cp"], ar=t["ar"], tnom=par["tnom"]).splitlines()


def _tfr_exprs(par, corner):
    """Resistance and end capacitance of rtfr in w, l, m and mm (SI units)."""
    t = par["tfr"]
    f = par["corners"][corner]
    r = (f"{f['rtfr']:g}*({t['rsh']:g}*l+{2 * t['rend']:g}e-6)/w"
         f"*(1+mm*{t['ar'] * 1e-8:g}/sqrt(w*l*m)*agauss(0,1,1))")
    c = f"{f['ctfr'] * t['ca'] * 0.5e-3:g}*w*l+{f['ctfr'] * t['cp'] * 1e-9:g}*(w+l)"
    return r, c


def _values(par, corner):
    f = par["corners"][corner]
    rm = {n: m["rsh"] * f["rm"] for n, m in par["metals"].items()}
    return f, rm


def ngspice_section(par, corner):
    f, rm = _values(par, corner)
    t = par["tfr"]
    out = []
    for n, rsh in rm.items():
        out += [
            f".subckt rm{n} p n w={par['metals'][n]['wmin']:g}u l=1u m=1",
            f"R1 p n r={{{rsh:g}*l/w}} tc1={par['rm']['tc1']:g} tc2={par['rm']['tc2']:g} m={{m}}",
            f".ends rm{n}",
            "",
        ]
    r, c = _tfr_exprs(par, corner)
    out += [
        f".subckt rtfr p n b w={t['wmin']:g}u l=1u m=1 mm=0",
        f"R1 p n r={{{r}}} tc1={t['tc1']:g} tc2={t['tc2']:g} m={{m}}",
        f"C1 p b c={{{c}}} m={{m}}",
        f"C2 n b c={{{c}}} m={{m}}",
        ".ends rtfr",
        "",
    ]
    for bot, top in mom_combinations():
        out += [
            f".subckt cmom_m{bot}m{top} p n w=1u l=1u m=1",
            f"C1 p n c={{{_mom_expr(par, bot, top, f['cmom'])}}} m={{m}}",
            f".ends cmom_m{bot}m{top}",
            "",
        ]
    out += ngspice_junctions(par, corner)
    return out


def xyce_section(par, corner):
    # Xyce applies the multiplier M of an X line itself
    f, rm = _values(par, corner)
    t = par["tfr"]
    out = []
    for n, rsh in rm.items():
        out += [
            f".subckt rm{n} p n params: w={par['metals'][n]['wmin']:g}u l=1u",
            f"R1 p n {{{rsh:g}*l/w}} tc={par['rm']['tc1']:g},{par['rm']['tc2']:g}",
            f".ends rm{n}",
            "",
        ]
    # m is 1 in the mismatch term: Xyce does not hand the multiplier to the subcircuit
    r, c = _tfr_exprs(par, corner)
    out += [
        f".subckt rtfr p n b params: w={t['wmin']:g}u l=1u mm=0",
        f"R1 p n {{{r.replace('w*l*m', 'w*l')}}} tc={t['tc1']:g},{t['tc2']:g}",
        f"C1 p b {{{c}}}",
        f"C2 n b {{{c}}}",
        ".ends rtfr",
        "",
    ]
    for bot, top in mom_combinations():
        out += [
            f".subckt cmom_m{bot}m{top} p n params: w=1u l=1u",
            f"C1 p n {{{_mom_expr(par, bot, top, f['cmom'])}}}",
            f".ends cmom_m{bot}m{top}",
            "",
        ]
    out += xyce_junctions(par, corner)
    return out


def vacask_section(par, corner):
    f, rm = _values(par, corner)
    t = par["tfr"]
    out = [
        'load "spice/resistor.osdi"',
        'load "capacitor.osdi"',
        "",
        f"model asap7_rm sp_resistor (model_tc1={par['rm']['tc1']:g} model_tc2={par['rm']['tc2']:g} tnom={par['tnom']})",
        f"model asap7_rtfr sp_resistor (model_tc1={t['tc1']:g} model_tc2={t['tc2']:g} tnom={par['tnom']})",
        "model asap7_cmom capacitor",
        "",
    ]
    for n, rsh in rm.items():
        out += [
            f"subckt rm{n}(p n)",
            f"  parameters w={par['metals'][n]['wmin']:g}u l=1u m=1",
            f"  r1 (p n) asap7_rm resistance={rsh:g}*l/w $mfactor=m",
            "ends",
            "",
        ]
    r, c = _tfr_exprs(par, corner)
    out += [
        "subckt rtfr(p n b)",
        f"  parameters w={t['wmin']:g}u l=1u m=1 mm=0",
        f"  r1 (p n) asap7_rtfr resistance={r} $mfactor=m",
        f"  c1 (p b) asap7_cmom c={c} $mfactor=m",
        f"  c2 (n b) asap7_cmom c={c} $mfactor=m",
        "ends",
        "",
    ]
    for bot, top in mom_combinations():
        out += [
            f"subckt cmom_m{bot}m{top}(p n)",
            "  parameters w=1u l=1u m=1",
            f"  c1 (p n) asap7_cmom c={_mom_expr(par, bot, top, f['cmom'])} $mfactor=m",
            "ends",
            "",
        ]
    out += vacask_junctions(par, corner)
    return out


def _junction(par, corner):
    """Diode and PNP model parameters per um^2 and the area in um^2 of one strip per fin."""
    j = par["junction"]
    js = j["js"] * par["corners"][corner]["js"]
    unit = j["strip"] * par["fin_pitch"]
    diode = f"is={js:g} n={j['n']:g} rs={j['rs']:g} cjo={j['cj']:g} m={j['mj']:g} vj={j['vj']:g} eg=1.12 xti=3 tnom={par['tnom']}"
    bjt = (f"is={js:g} bf={j['bf']:g} nf={j['n']:g} br={j['br']:g} nr={j['n']:g} re={j['rs']:g} rb={10 * j['rs']:g} "
           f"cje={j['cj']:g} mje={j['mj']:g} vje={j['vj']:g} cjc={j['cj'] / 4:g} mjc={j['mj']:g} vjc={j['vj']:g} "
           f"eg=1.12 xti=3 tnom={par['tnom']}")
    return diode, bjt, unit


def ngspice_junctions(par, corner):
    diode, bjt, unit = _junction(par, corner)
    return [
        f".model asap7_dio d ({diode})",
        f".model asap7_pnp pnp ({bjt})",
        ".subckt ndio a k nfin=4 m=1",
        f"D1 a k asap7_dio area={{{unit:g}*nfin*m}}",
        ".ends ndio",
        ".subckt pdio a k nfin=4 m=1",
        f"D1 a k asap7_dio area={{{unit:g}*nfin*m}}",
        ".ends pdio",
        ".subckt pnp c b e nfin=4 m=1",
        f"Q1 c b e asap7_pnp area={{{unit:g}*nfin*m}}",
        ".ends pnp",
        "",
    ]


def xyce_junctions(par, corner):
    # Xyce applies the multiplier M of an X line itself
    diode, bjt, unit = _junction(par, corner)
    return [
        f".model asap7_dio d ({diode})",
        f".model asap7_pnp pnp ({bjt})",
        ".subckt ndio a k params: nfin=4",
        f"D1 a k asap7_dio area={{{unit:g}*nfin}}",
        ".ends ndio",
        ".subckt pdio a k params: nfin=4",
        f"D1 a k asap7_dio area={{{unit:g}*nfin}}",
        ".ends pdio",
        ".subckt pnp c b e params: nfin=4",
        f"Q1 c b e asap7_pnp area={{{unit:g}*nfin}}",
        ".ends pnp",
        "",
    ]


def vacask_junctions(par, corner):
    diode, bjt, unit = _junction(par, corner)
    return [
        'load "spice/diode.osdi"',
        'load "spice/bjt.osdi"',
        f"model asap7_dio sp_diode ({diode})",
        f"model asap7_pnp sp_bjt (type=-1 {bjt})",
        "subckt ndio(a k)",
        "  parameters nfin=4 m=1",
        f"  d1 (a k) asap7_dio area={unit:g}*nfin $mfactor=m",
        "ends",
        "subckt pdio(a k)",
        "  parameters nfin=4 m=1",
        f"  d1 (a k) asap7_dio area={unit:g}*nfin $mfactor=m",
        "ends",
        "subckt pnp(c b e)",
        "  parameters nfin=4 m=1",
        f"  q1 (c b e c) asap7_pnp area={unit:g}*nfin $mfactor=m",
        "ends",
        "",
    ]


def write_json(par, path):
    with open(path, "w") as f:
        json.dump(par, f, indent=1)
        f.write("\n")
