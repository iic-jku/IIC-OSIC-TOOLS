# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""KLayout PCell library ASAP7: one PCell per device with a simulation model.

  nmos, pmos   FinFET {n,p}mos_{lvt,rvt,slvt,sram} and the IO FinFET {n,p}mos_io18
  ncap, pcap   MOS capacitor of the symbols ncap_* and pcap_*
  ptap, ntap   substrate contact for NMOS rows, well contact for PMOS rows
               (no model: the body of a FinFET is a terminal of its model)
  ndio, pdio   junction diodes, pnp the vertical PNP, each with its body taps
  rm           metal resistor rm1 ... rm9
  rtfr         TiN thin-film resistor
  cmom         woven MOM capacitor cmom_m<bot>m<top>
  pad          pad plate over M9 stripes (no model, extracted as capacitance)

The parameters are the ones of the models (w and l in um). The drawing code
is asap7_layout.py, which also writes the same cells from the command line.
The resistors and the MOM capacitor are an IIC-OSIC-TOOLS addition, ASAP7
defines no passives. pymacros/asap7_pcells.lym registers the library when
KLayout starts with the ASAP7 technology directory in KLAYOUT_PATH.
"""

import pya

import asap7_layout as gen

LIBRARY = "ASAP7"
VTS = ["rvt", "lvt", "slvt", "sram", "io18"]


class DevicePCell(pya.PCellDeclarationHelper):
    """Common part: draw through asap7_layout, show an error as a text."""

    def __init__(self):
        super().__init__()
        self.passives = gen.load_parameters()

    def choice(self, name, text, values, default):
        self.param(name, self.TypeString if isinstance(default, str) else self.TypeInt, text,
                   default=default, choices=[(str(v), v) for v in values])

    def draw(self, cell):
        raise NotImplementedError

    def produce_impl(self):
        try:
            self.draw(gen.Cell(layout=self.layout, cell=self.cell))
        except gen.PassiveError as e:
            # no geometry for parameters that cannot be drawn, only the reason
            self.cell.clear()
            text = pya.DText(f"{self.display_text_impl()}: {e}", pya.DTrans(0.0, 0.0))
            self.cell.shapes(self.layout.layer(235, 0)).insert(text)


class MOS(DevicePCell):
    def __init__(self, kind, cap):
        super().__init__()
        self.kind, self.cap = kind, cap
        self.choice("vt", "Threshold flavor", VTS, "rvt")
        self.choice("l", "Gate length in nm (20 is the length of ASAP7, io18 takes 80, 160 or 240)",
                    sorted(set(self.passives["mos_lengths"] + self.passives["io_lengths"])), 20)
        self.param("nfin", self.TypeInt, "Fins per finger", default=4 if cap else 3)
        self.param("nf", self.TypeInt, "Fingers (m of the model)", default=1)
        if not cap:
            self.param("strap", self.TypeBoolean, "Tie sources and drains on M2", default=False)

    def display_text_impl(self):
        return f"{self.kind}{'cap' if self.cap else 'mos'}_{self.vt} l={self.l}n nfin={self.nfin} m={self.nf}"

    def coerce_parameters_impl(self):
        self.nfin = max(1, self.nfin)
        self.nf = max(1, self.nf)
        # a length of the other device family becomes the shortest valid one
        lengths = self.passives["io_lengths" if self.vt == "io18" else "mos_lengths"]
        if self.l not in lengths:
            self.l = lengths[0]

    def draw(self, cell):
        gen.draw_mos(self.passives, cell, self.kind, self.vt, self.nfin, self.nf,
                     strap=(not self.cap and self.strap), cap=self.cap, l=self.l)


class Tap(DevicePCell):
    def __init__(self, kind):
        super().__init__()
        self.kind = kind
        self.param("nfin", self.TypeInt, "Fins (same as the FinFET row)", default=3)

    def display_text_impl(self):
        return f"{'pn'[self.kind == 'p']}tap nfin={self.nfin}"

    def coerce_parameters_impl(self):
        self.nfin = max(1, self.nfin)

    def draw(self, cell):
        gen.draw_mos(self.passives, cell, self.kind, "rvt", self.nfin, 1, tap=True)


class Junction(DevicePCell):
    def __init__(self, device):
        super().__init__()
        self.device = device
        self.param("nfin", self.TypeInt, "Fins per strip", default=4)
        self.param("m", self.TypeInt, "Strips", default=1)

    def display_text_impl(self):
        return f"{self.device} nfin={self.nfin} m={self.m}"

    def coerce_parameters_impl(self):
        self.nfin = max(1, self.nfin)
        self.m = max(1, self.m)

    def draw(self, cell):
        gen.draw_junction(self.passives, cell, self.device, self.nfin, self.m)


class MetalResistor(DevicePCell):
    def __init__(self):
        super().__init__()
        self.choice("n", "Metal level (model rm<n>)", range(1, 10), 2)
        self.param("w", self.TypeDouble, "Width", default=0.018, unit="um")
        self.param("l", self.TypeDouble, "Length", default=1.0, unit="um")

    def display_text_impl(self):
        return f"rm{self.n} w={self.w:g}u l={self.l:g}u"

    def coerce_parameters_impl(self):
        self.w = max(self.w, self.passives["metals"][str(self.n)]["wmin"])

    def draw(self, cell):
        gen.draw_rm(self.passives, cell, self.n, self.w, self.l)


class ThinFilmResistor(DevicePCell):
    def __init__(self):
        super().__init__()
        self.param("w", self.TypeDouble, "Width", default=0.108, unit="um")
        self.param("l", self.TypeDouble, "Length between the contacts", default=1.0, unit="um")

    def display_text_impl(self):
        return f"rtfr w={self.w:g}u l={self.l:g}u"

    def coerce_parameters_impl(self):
        self.w = max(self.w, self.passives["tfr"]["wmin"])
        self.l = max(self.l, self.passives["tfr"]["lmin"])

    def draw(self, cell):
        gen.draw_rtfr(self.passives, cell, self.w, self.l)


class MOMCapacitor(DevicePCell):
    def __init__(self):
        super().__init__()
        lo, hi = self.passives["mom_layers"]
        self.choice("bot", "Lowest metal level", range(lo, hi), 4)
        self.choice("top", "Highest metal level", range(lo + 1, hi + 1), 7)
        self.param("w", self.TypeDouble, "Width (x)", default=1.0, unit="um")
        self.param("l", self.TypeDouble, "Length (y)", default=1.0, unit="um")

    def display_text_impl(self):
        return f"cmom_m{self.bot}m{self.top} w={self.w:g}u l={self.l:g}u"

    def coerce_parameters_impl(self):
        self.top = max(self.top, self.bot + 1)

    def draw(self, cell):
        gen.draw_cmom(self.passives, cell, self.bot, self.top, self.w, self.l)


class Pad(DevicePCell):
    def __init__(self):
        super().__init__()
        self.param("w", self.TypeDouble, "Width (x)", default=40.0, unit="um")
        self.param("l", self.TypeDouble, "Length (y)", default=40.0, unit="um")

    def display_text_impl(self):
        return f"pad w={self.w:g}u l={self.l:g}u"

    def coerce_parameters_impl(self):
        self.w = max(self.w, 5.0)
        self.l = max(self.l, 5.0)

    def draw(self, cell):
        gen.draw_pad(cell, self.w, self.l)


class ASAP7Library(pya.Library):
    def __init__(self):
        self.description = "ASAP7 devices (FinFETs, MOS capacitors and the passives of IIC-OSIC-TOOLS)"
        self.technology = "asap7"
        for kind in ("n", "p"):
            self.layout().register_pcell(f"{kind}mos", MOS(kind, cap=False))
            self.layout().register_pcell(f"{kind}cap", MOS(kind, cap=True))
        # ptap is the p+ contact of the substrate (NMOS rows), ntap the n+ contact of the well
        self.layout().register_pcell("ptap", Tap("n"))
        self.layout().register_pcell("ntap", Tap("p"))
        for device in ("ndio", "pdio", "pnp"):
            self.layout().register_pcell(device, Junction(device))
        self.layout().register_pcell("rm", MetalResistor())
        self.layout().register_pcell("rtfr", ThinFilmResistor())
        self.layout().register_pcell("cmom", MOMCapacitor())
        self.layout().register_pcell("pad", Pad())
        self.register(LIBRARY)


def register():
    ASAP7Library()
