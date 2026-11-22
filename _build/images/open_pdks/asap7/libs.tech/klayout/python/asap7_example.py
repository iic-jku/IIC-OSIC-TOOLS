#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Example of an analog layout in ASAP7: a common-source amplifier.

Writes cs_amp.gds and cs_amp.cdl into the given directory (default: the
working directory). The amplifier is an NMOS nmos_rvt (2 fingers of 3 fins)
with its substrate tap, the thin-film resistor rtfr as load to vdd and the
MOM capacitor cmom_m2m3 from the output to vss:

    X1 out in vss vss nmos_rvt l=20n nfin=3 m=2
    X2 vdd out vss rtfr w=108n l=1u
    X3 out vss cmom_m2m3 w=0.36u l=0.6u

The devices are drawn by asap7_layout.py, as the PCells of the library ASAP7
draw them, and wired on M1 to M3. The layout is DRC clean and matches the
netlist, with the body of the FinFET and the substrate of the resistor:

    klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/drc/asap7.lydrc \\
        -rd input=cs_amp.gds -rd topcell=cs_amp -rd report=cs_amp.lyrdb
    klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs \\
        -rd input=cs_amp.gds -rd topcell=cs_amp -rd schematic=cs_amp.cdl \\
        -rd body=true -rd pex=cs_amp.pex.spice

cs_amp.pex.spice is the netlist for simulation with the wire capacitances,
-rd pex_res=true adds the wire resistances.
The resistor, the capacitor and the rules they follow are an IIC-OSIC-TOOLS
addition, ASAP7 defines no passives (see the PDK README).
"""

import sys
from pathlib import Path

import asap7_layout as gen

M1, M2, M3, V1, V2 = 19, 20, 30, 21, 25

NETLIST = """* Common-source amplifier, the schematic of cs_amp.gds
.subckt cs_amp in out vdd vss
X1 out in vss vss nmos_rvt l=20n nfin=3 m=2
X2 vdd out vss rtfr w=108n l=1u
X3 out vss cmom_m2m3 w=0.36u l=0.6u
.ends
"""


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    par = gen.load_parameters()
    c = gen.Cell("cs_amp")

    # NMOS at the origin, its tap abutting on the right. The strap puts the
    # sources on the M2 bar at y = -36 nm and the drains on the one at y = 0.
    gen.draw_mos(par, c.at(0, 0), "n", "rvt", 3, 2, strap=True)
    gen.draw_mos(par, c.at(0.216, 0), "n", "rvt", 3, 1, tap=True)
    # resistor left of the NMOS, its right contact (n) at x = -78 nm
    gen.draw_rtfr(par, c.at(-1.078, 0.060), 0.108, 1.0)
    # capacitor below, its first M3 finger (p) at x = -35 nm, the last (n) at 217 nm
    gen.draw_cmom(par, c.at(-0.080, -0.700), 2, 3, 0.36, 0.6)

    # out: drain bar to the resistor contact and to the first capacitor finger
    c.box(M2, -0.090, 0, 0.036, 0.018)
    c.box(M1, -0.078, -0.005, -0.060, 0.060)
    c.box(V1, -0.078, 0, -0.060, 0.018)
    c.box(M3, -0.035, -0.100, -0.017, 0.023)
    c.box(V2, -0.035, 0, -0.017, 0.018)
    # vss: source bar to the tap and to the last capacitor finger
    c.box(M2, 0.180, -0.036, 0.290, -0.018)
    c.box(M1, 0.261, -0.041, 0.279, 0)
    c.box(V1, 0.261, -0.036, 0.279, -0.018)
    c.box(M3, 0.217, -0.100, 0.235, -0.013)
    c.box(V2, 0.217, -0.036, 0.235, -0.018)

    c.label(M1, "vdd", -1.087, 0.100)
    c.label(M1, "in", 0.090, 0.135)
    c.label(M2, "out", 0.100, 0.009)
    c.label(M2, "vss", 0.100, -0.027)

    c.write(str(out / "cs_amp.gds"))
    (out / "cs_amp.cdl").write_text(NETLIST)
    print(f"[INFO] Wrote {out / 'cs_amp.gds'} and {out / 'cs_amp.cdl'}")


if __name__ == "__main__":
    main()
