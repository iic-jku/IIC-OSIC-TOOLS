#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Draw the devices of ASAP7 in IIC-OSIC-TOOLS as GDS cells.

Every device with a simulation model has a layout here. Sizes are in um and
match the parameters w and l of the models. The pins are labeled.

  asap7_layout.py mos --type n --vt rvt --nfin 3 --nf 2 [--lg 60] -o nmos.gds
      FinFET {n,p}mos_{lvt,rvt,slvt,sram} with nf gate fingers of nfin fins
      between two dummy gates, after the transistors of the standard cells.
      --lg is the gate length in nm (20, 24, 28, 36, 60 or 80, the gates
      keep their spacing of 34 nm). --vt 18 is the 1.8 V IO FinFET
      {n,p}mos_18 (--lg 80, 160 or 240, gate spacing 100 nm).
      All gates are tied on M1 (pin G). With --strap the sources and the
      drains are tied on M2 (pins S and D), otherwise every source and
      drain ends on its own M1 strip. --cap ties all of them to one pin B,
      which is the MOS capacitor of the symbols ncap_* and pcap_*.
      --tap draws the body contact that abuts such a row instead: the
      substrate contact for --type n, the well contact for --type p (pin B).
  asap7_layout.py pnp --nfin 4 -m 3 -o pnp.gds
      Junction diodes ndio (n+ in the substrate) and pdio (p+ in the well) and
      the vertical PNP pnp, with m strips of nfin fins and their body taps.
  asap7_layout.py rm -n 2 -w 0.018 -l 1.8 -o rm2.gds
      Metal resistor rm<n> on M<n>: a wire of width w with the marker
      RES_M<n> over the length l.
  asap7_layout.py rtfr -w 0.108 -l 1 -o rtfr.gds
      TiN thin-film resistor: TFR film, both ends contacted by V0 and M1,
      l is the distance between the two M1 contacts.
  asap7_layout.py cmom --bot 4 --top 7 -w 1 -l 2 -o cmom.gds
      Woven MOM capacitor cmom_m<bot>m<top> with the footprint w (x) by l (y).
      p is the first finger of the top layer, n the last one.

  asap7_layout.py pad -w 40 -l 40 -o pad.gds
      Pad plate on the layer Pad over M9 stripes with V9 (pin pad). It has
      no model, its capacitance comes from the extraction (-rd pex=).

--cell names the cell, the default is the device name. The resistors and
the MOM capacitor are an IIC-OSIC-TOOLS addition, ASAP7 defines no passives
(see the PDK README). Their parameters are read from asap7_passives.json in
the technology directory.

The same drawing functions back the PCells of the KLayout library ASAP7
(asap7_pcells.py).
"""

import argparse
import json
import math
import sys
from pathlib import Path

try:
    import pya as db  # inside the KLayout application
except ImportError:
    import klayout.db as db

DBU = 0.00025
PAR_FILE = Path(__file__).resolve().parent.parent / "tech" / "asap7_passives.json"
V0_LAYER = 18
M1_PIN_END = 0.030   # um of M1 past the thin-film resistor on the pin side
TFR_ENC = 0.005      # um of TFR around V0
# via layer below each metal level
VIA_BELOW = {2: 21, 3: 25, 4: 35, 5: 45, 6: 55, 7: 65}


class PassiveError(Exception):
    """A device cannot be drawn with the given parameters."""


class Cell:
    """Draws into a new layout, or into a given cell (the PCells do that)."""

    def __init__(self, name=None, layout=None, cell=None, dx=0.0, dy=0.0, labels=True):
        # dx, dy in um shift everything drawn, labels=False leaves the pin names out
        self.dx, self.dy, self.labels = dx, dy, labels
        if cell is None:
            self.layout = db.Layout()
            self.layout.dbu = DBU
            self.cell = self.layout.create_cell(name)
        else:
            self.layout, self.cell = layout, cell

    def dbu(self, um):
        um = round(um, 6)
        v = um / self.layout.dbu
        if abs(v - round(v)) > 1e-6:
            raise PassiveError(f"{um:g} um is not on the {self.layout.dbu:g} um grid")
        return round(v)

    def box(self, layer, x1, y1, x2, y2, datatype=0):
        li = self.layout.layer(layer, datatype)
        box = db.Box(self.dbu(x1 + self.dx), self.dbu(y1 + self.dy), self.dbu(x2 + self.dx), self.dbu(y2 + self.dy))
        self.cell.shapes(li).insert(box)

    def label(self, layer, text, x, y):
        if not self.labels:
            return
        li = self.layout.layer(layer, 251)
        self.cell.shapes(li).insert(db.Text(text, db.Trans(self.dbu(x + self.dx), self.dbu(y + self.dy))))

    def at(self, dx, dy):
        """The same cell for a device placed at dx, dy in um, without its pin names."""
        return Cell(layout=self.layout, cell=self.cell, dx=dx, dy=dy, labels=False)

    def write(self, path):
        self.layout.write(path)


def load_parameters():
    return json.loads(PAR_FILE.read_text())


def snap(um, grid=0.001):
    return round(um / grid) * grid


def draw_rm(par, c, n, w, l):
    m = par["metals"][str(n)]
    if w < m["wmin"] - 1e-9:
        raise PassiveError(f"w is below the minimum width of M{n}, {m['wmin']} um")
    head = max(3 * m["wmin"], 0.044)
    horizontal = m["dir"] == "H"

    def rect(layer, a1, a2, datatype=0):
        # a: along the wire, the wire is w wide
        if horizontal:
            c.box(layer, a1, 0, a2, w, datatype)
        else:
            c.box(layer, 0, a1, w, a2, datatype)

    rect(m["layer"], -head, l + head)
    rect(par["res_marker_layer"], 0, l, datatype=n)
    for name, a in (("p", -head / 2), ("n", l + head / 2)):
        x, y = (a, w / 2) if horizontal else (w / 2, a)
        c.label(m["layer"], name, snap(x), snap(y))


def draw_rtfr(par, c, w, l):
    t = par["tfr"]
    m1 = par["metals"]["1"]
    if w < t["wmin"] - 1e-9 or l < t["lmin"] - 1e-9:
        raise PassiveError(f"rtfr needs w >= {t['wmin']} um and l >= {t['lmin']} um")
    wc = m1["wmin"]
    layer, datatype = par["tfr_layer"]
    c.box(layer, -wc - TFR_ENC, 0, l + wc + TFR_ENC, w, datatype)
    # p leaves the film downwards, n upwards
    for name, x, y1, y2 in (("p", -wc, -M1_PIN_END, w), ("n", l, 0, w + M1_PIN_END)):
        c.box(m1["layer"], x, y1, x + wc, y2)
        c.box(V0_LAYER, x, TFR_ENC, x + wc, w - TFR_ENC)
        c.label(m1["layer"], name, snap(x + wc / 2), snap(y1 + 0.009 if name == "p" else y2 - 0.009))


def mom_fingers(par, n, w, l):
    """Finger positions (lower edge across the direction) and length of level n."""
    m = par["metals"][str(n)]
    pitch = m["wmin"] + m["smin"]
    across, along = (l, w) if m["dir"] == "H" else (w, l)
    nf = 2 * math.floor((across - 2 * par["mom_edge"] + m["smin"] + 1e-9) / (2 * pitch))
    if nf < 2:
        raise PassiveError(f"cmom is too small for two fingers on M{n}")
    span = nf * pitch - m["smin"]
    start = math.floor((across - span) / 2 / 0.001 + 1e-6) * 0.001
    return [snap(start + i * pitch) for i in range(nf)], along


def draw_cmom(par, c, bot, top, w, l):
    lo, hi = par["mom_layers"]
    if not lo <= bot < top <= hi:
        raise PassiveError(f"cmom needs M{lo} <= bot < top <= M{hi}")
    layer, datatype = par["momcap_layer"]
    c.box(layer, 0, 0, w, l, datatype)
    pos = {}
    for n in range(bot, top + 1):
        m = par["metals"][str(n)]
        pos[n], along = mom_fingers(par, n, w, l)
        for p in pos[n]:
            if m["dir"] == "H":
                c.box(m["layer"], 0, p, along, p + m["wmin"])
            else:
                c.box(m["layer"], p, 0, p + m["wmin"], along)
    # Even fingers are plate p, odd fingers plate n. Each finger gets one via
    # to the first (p) or last (n) finger of the layer below and above.
    for n in range(bot + 1, top + 1):
        up, dn = par["metals"][str(n)], par["metals"][str(n - 1)]
        pairs = {(i, i % 2 * (len(pos[n - 1]) - 1)) for i in range(len(pos[n]))}
        pairs |= {(j % 2 * (len(pos[n]) - 1), j) for j in range(len(pos[n - 1]))}
        for i, j in pairs:
            pu, pd = pos[n][i], pos[n - 1][j]
            if up["dir"] == "H":
                c.box(VIA_BELOW[n], pd, pu, pd + dn["wmin"], pu + up["wmin"])
            else:
                c.box(VIA_BELOW[n], pu, pd, pu + up["wmin"], pd + dn["wmin"])
    m = par["metals"][str(top)]
    for name, p in (("p", pos[top][0]), ("n", pos[top][-1])):
        mid = snap(p + m["wmin"] / 2)
        x, y = (0.02, mid) if m["dir"] == "H" else (mid, 0.02)
        c.label(m["layer"], name, x, y)


# FinFET geometry in nm, taken from INVx1 of asap7sc7p5t: gate length 20 on a
# pitch of 54, fin pitch 27, fin width 7. Longer gates keep the gate spacing.
FIN_PITCH = 27
MOS_LAYERS = {"nwell": 1, "fin": 2, "gate": 7, "gcut": 10, "active": 11, "nselect": 12, "pselect": 13,
              "lig": 16, "lisd": 17, "v0": 18, "m1": 19, "m2": 20, "v1": 21, "sdt": 88}
VT_LAYERS = {"rvt": None, "lvt": 98, "slvt": 97, "sram": 110}


def draw_mos(par, c, kind, vt, nfin, nf, strap=False, cap=False, tap=False, l=None):
    """FinFET with nf fingers of nfin fins, kind "n" or "p".

    The layout is one transistor row of a standard cell: fins along x, gates
    at the gate pitch with a dummy gate on each side, the active area ending
    9 nm before the dummy gates, SDT, LISD, V0 and an M1 strip on every source
    and drain, and LIG with V0 and M1 above the active area on the gates.
    vt "18" is the 1.8 V IO FinFET: the layer TG over the row, a gate
    length of 80 nm or more and a gate spacing of 100 nm.

    tap draws the body contact of such a row instead, after TAPCELL: two dummy
    gates with a contacted active area of the opposite implant between them.
    kind "n" with tap is the substrate contact next to NMOS (p implant),
    kind "p" the well contact next to PMOS (n implant in the well). A row has
    the same height for the same nfin, so taps and FinFETs abut.
    """
    io = vt == "18"
    if kind not in ("n", "p") or (vt not in VT_LAYERS and not io):
        raise PassiveError("mos needs the type n or p and the vt lvt, rvt, slvt, sram or 18")
    if nfin < 1 or nf < 1:
        raise PassiveError("mos needs nfin >= 1 and nf >= 1")
    lengths = par["io_lengths"] if io else par["mos_lengths"]
    if tap or l is None:
        l = lengths[0]
    if l not in lengths:
        raise PassiveError(f"{"1.8 V IO" if io else "core"} mos needs a gate length of {', '.join(str(x) for x in lengths)} nm")
    L = MOS_LAYERS
    space = par["io_gate_space"] if io else par["mos_gate_space"]
    cpp = l + space
    if tap:
        nf = 0

    def box(layer, x1, y1, x2, y2):
        c.box(L[layer] if isinstance(layer, str) else layer, x1 / 1000, y1 / 1000, x2 / 1000, y2 / 1000)

    def gate(j):
        """Left edge of gate j, 0 and nf + 1 are the dummy gates."""
        return 17 + cpp * j

    def column(i):
        """Left edge of the 24 nm source or drain contact right of gate i."""
        return gate(i) + l + (space - 24) // 2

    width = cpp * (nf + 2)
    top = FIN_PITCH * (nfin + 1)        # upper edge of the active area
    cut = top + 49                      # lower edge of the gate cut above the gate contacts
    y0, y1 = 0, cut + 27                # implant region, the gates end at y1
    # lower end of the source and drain M1 strips, 5 nm past the V1 of the strap
    low = -41 if (strap or cap) else 0

    # a tap has the implant of the body: p in the substrate, n in the well
    box("nselect" if (kind == "n") != tap else "pselect", 0, y0, width, y1)
    if kind == "p":
        box("nwell", 0, y0, width, y1)
    if io:
        c.box(par["tg_layer"][0], 0, (y0 - 22) / 1000, width / 1000, (cut + 44) / 1000, par["tg_layer"][1])
    elif VT_LAYERS[vt] and not tap:
        box(VT_LAYERS[vt], 0, y0, width, y1)
    k = 0
    while 10 + FIN_PITCH * k + 7 <= y1:
        box("fin", 0, 10 + FIN_PITCH * k, width, 17 + FIN_PITCH * k)
        k += 1
    for j in range(nf + 2):
        box("gate", gate(j), -5, gate(j) + l, y1)
    box("gcut", 0, -22, width, 22)
    box("gcut", 0, cut, width, cut + 44)
    box("active", column(0) + 4, 27, column(nf) + 20, top)

    # sources and drains
    for i in range(nf + 1):
        x = column(i)
        box("sdt", x, 27, x + 24, top)
        box("lisd", x, 27, x + 24, top)
        box("v0", x + 3, 27, x + 21, 45)
        if nfin >= 3:
            box("v0", x + 3, top - 27, x + 21, top - 9)
        box("m1", x + 3, low, x + 21, top - 9)
    if tap:
        c.label(L["m1"], "B", (column(0) + 12) / 1000, 0.009)
        return
    # gates: LIG from 17 nm left of the first gate to 2 nm right of the last one
    g = gate(1)
    box("lig", g - 17, top + 16, g + l + 2 + cpp * (nf - 1), top + 38)
    for j in range(nf):
        box("v0", g - 16 + cpp * j, top + 18, g + 2 + cpp * j, top + 36)
    box("m1", g - 25, top + 18, g + 11 + cpp * (nf - 1), top + 36)
    c.label(L["m1"], "G", (g - 7) / 1000, (top + 27) / 1000)

    bar = (column(0) - 6, column(nf) + 30)
    if cap:
        box("m2", bar[0], -36, bar[1], -18)
        for i in range(nf + 1):
            box("v1", column(i) + 3, -36, column(i) + 21, -18)
        c.label(L["m2"], "B", (column(0) + 12) / 1000, -0.027)
    elif strap:
        # sources (even columns) on the lower M2 bar, drains on the upper one
        for name, y, first in (("S", -36, 0), ("D", 0, 1)):
            box("m2", bar[0], y, bar[1], y + 18)
            for i in range(first, nf + 1, 2):
                box("v1", column(i) + 3, y, column(i) + 21, y + 18)
            c.label(L["m2"], name, (column(0) - 2) / 1000, (y + 9) / 1000)
    else:
        for i in range(nf + 1):
            c.label(L["m1"], "SD"[i % 2] + (str(i // 2 + 1) if nf > 1 else ""), (column(i) + 12) / 1000, 0.009)


def draw_junction(par, c, device, nfin, m):
    """Junction diode ndio or pdio, or the vertical PNP pnp, with its contacts.

    The junction is m strips of contacted active area between dummy gates,
    like the tap of a FinFET row but with the implant of a source or drain,
    under the marker DIODE or BJT. The strips are tied on M2. The tap of the
    body follows on the right: the substrate tap for ndio (pin a), the well tap
    for pdio (pin k) and pnp (pin b), and for pnp the substrate tap after it
    (pin c).
    """
    if device not in ("ndio", "pdio", "pnp"):
        raise PassiveError("junction devices are ndio, pdio and pnp")
    if nfin < 1 or m < 1:
        raise PassiveError(f"{device} needs nfin >= 1 and m >= 1")
    L = MOS_LAYERS
    in_well = device != "ndio"

    def box(layer, x1, y1, x2, y2, datatype=0):
        c.box(L[layer] if isinstance(layer, str) else layer, x1 / 1000, y1 / 1000, x2 / 1000, y2 / 1000, datatype)

    width = 54 * (m + 1)
    top = FIN_PITCH * (nfin + 1)
    cut = top + 49
    y1 = cut + 27
    box("pselect" if in_well else "nselect", 0, 0, width, y1)
    if in_well:
        box("nwell", 0, 0, width, y1)
    marker = par["bjt_layer"] if device == "pnp" else par["diode_layer"]
    box(marker[0], 0, 0, width, y1, marker[1])
    k = 0
    while 10 + FIN_PITCH * k + 7 <= y1:
        box("fin", 0, 10 + FIN_PITCH * k, width, 17 + FIN_PITCH * k)
        k += 1
    for j in range(m + 1):
        box("gate", 17 + 54 * j, -5, 37 + 54 * j, y1)
    box("gcut", 0, -22, width, 22)
    box("gcut", 0, cut, width, cut + 44)
    for i in range(m):
        x = 42 + 54 * i
        box("active", x + 4, 27, x + 20, top)
        box("sdt", x, 27, x + 24, top)
        box("lisd", x, 27, x + 24, top)
        box("v0", x + 3, 27, x + 21, 45)
        box("m1", x + 3, -41, x + 21, top - 9)
        box("v1", x + 3, -36, x + 21, -18)
    box("m2", 36, -36, 72 + 54 * (m - 1), -18)
    c.label(L["m2"], {"ndio": "k", "pdio": "a", "pnp": "e"}[device], 0.054, -0.027)

    # body contacts: a tap row of the same height, its M1 strip is the pin
    taps = {"ndio": [("n", "a")], "pdio": [("p", "k")], "pnp": [("p", "b"), ("n", "c")]}[device]
    for i, (kind, pin) in enumerate(taps):
        x0 = (width + 108 * i) / 1000
        draw_mos(par, c.at(c.dx + x0, c.dy), kind, "rvt", nfin, 1, tap=True)
        c.label(L["m1"], pin, x0 + 0.054, 0.009)


PAD_LAYER, V9_LAYER, M9_LAYER = 96, 95, 90


def draw_pad(c, w, l):
    """Pad: a plate on the layer Pad over M9 stripes, tied by V9.

    ASAP7 limits the width of M9 to 2 um, so the metal under the pad is a set
    of M9 stripes of 1 um at a pitch of 2.5 um, each with a V9 of 40 nm by
    120 nm every 2 um. The pin pad is on the first stripe. ASAP7 has the layer Pad but no
    rule for a bond pad, a bump or a passivation opening, so this is a probe
    and connection plate, not a qualified bond pad.
    """
    if w < 5 or l < 5:
        raise PassiveError("pad needs w >= 5 um and l >= 5 um")
    c.box(PAD_LAYER, 0, 0, w, l)
    x = 1.0
    while x + 1.0 <= w - 1.0 + 1e-9:
        c.box(M9_LAYER, x, 0.5, x + 1.0, l - 0.5)
        y = 1.0
        while y + 0.12 <= l - 1.0 + 1e-9:
            c.box(V9_LAYER, x + 0.48, y, x + 0.52, y + 0.12)
            y += 2.0
        x += 2.5
    c.label(M9_LAYER, "pad", 1.5, 1.5)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("device", choices=["mos", "ndio", "pdio", "pnp", "rm", "rtfr", "cmom", "pad"])
    ap.add_argument("-m", type=int, default=1, help="strips of ndio, pdio and pnp")
    ap.add_argument("--type", choices=["n", "p"], default="n", help="polarity of mos")
    ap.add_argument("--vt", choices=list(VT_LAYERS) + ["18"], default="rvt",
                    help="threshold flavor of mos, 18 is the 1.8 V IO FinFET")
    ap.add_argument("--nfin", type=int, default=3, help="fins per finger of mos")
    ap.add_argument("--nf", type=int, default=1, help="gate fingers of mos")
    ap.add_argument("--lg", type=int, help="gate length of mos in nm: 20 (default), 24, 28, 36, 60 or 80, "
                    "for vt 18 80 (default), 160 or 240")
    ap.add_argument("--strap", action="store_true", help="mos: tie sources and drains on M2")
    ap.add_argument("--cap", action="store_true", help="mos: MOS capacitor, sources and drains on one pin")
    ap.add_argument("--tap", action="store_true", help="mos: body contact for a row of this type and nfin")
    ap.add_argument("-n", type=int, help="metal level of rm, 1 to 9")
    ap.add_argument("--bot", type=int, help="lowest metal level of cmom")
    ap.add_argument("--top", type=int, help="highest metal level of cmom")
    ap.add_argument("-w", type=float, help="width in um")
    ap.add_argument("-l", type=float, help="length in um")
    ap.add_argument("-o", "--output", required=True, help="GDS file to write")
    ap.add_argument("--cell", help="cell name")
    args = ap.parse_args()
    par = load_parameters()
    try:
        c = draw(par, args)
    except PassiveError as e:
        sys.exit(f"[ERROR] {e}")
    c.write(args.output)
    print(f"[INFO] Wrote {args.output} (cell {c.cell.name})")


def draw(par, args):
    if args.device == "mos":
        name = f"{'pn'[args.type == 'p']}tap" if args.tap else f"{args.type}{'cap' if args.cap else 'mos'}_{args.vt}"
        c = Cell(args.cell or name)
        draw_mos(par, c, args.type, args.vt, args.nfin, args.nf, args.strap, args.cap, args.tap, args.lg)
        return c
    if args.device in ("ndio", "pdio", "pnp"):
        c = Cell(args.cell or args.device)
        draw_junction(par, c, args.device, args.nfin, args.m)
        return c
    if args.w is None or args.l is None:
        sys.exit(f"[ERROR] {args.device} needs -w and -l")
    if args.device == "pad":
        c = Cell(args.cell or "pad")
        draw_pad(c, args.w, args.l)
        return c
    if args.device == "rm":
        if args.n is None or str(args.n) not in par["metals"]:
            sys.exit("[ERROR] rm needs -n 1 ... 9")
        c = Cell(args.cell or f"rm{args.n}")
        draw_rm(par, c, args.n, args.w, args.l)
    elif args.device == "rtfr":
        c = Cell(args.cell or "rtfr")
        draw_rtfr(par, c, args.w, args.l)
    else:
        if args.bot is None or args.top is None:
            sys.exit("[ERROR] cmom needs --bot and --top")
        c = Cell(args.cell or f"cmom_m{args.bot}m{args.top}")
        draw_cmom(par, c, args.bot, args.top, args.w, args.l)
    return c


if __name__ == "__main__":
    main()
