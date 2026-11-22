#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""gm/ID lookup tables for the ASAP7 FinFETs, for pygmid.

Sweeps one ASAP7 device in ngspice over VGS, VDS, VSB and the gate length
and writes a pickle that pygmid.Lookup reads:

    from pygmid import Lookup
    nmos = Lookup("asap7_nmos_rvt.pkl")
    gm_id = nmos.lookup("GM_ID", VGS=0.4, VDS=0.35)

The table holds ID, VT, GM, GMB, GDS, CGG, CGS, CGD, CDD, CSS (all
magnitudes, so the PMOS table reads like the NMOS one) on the grid
L x VGS x VDS x VSB. L is in um. W is the effective width
nfin x 27 nm in um, so ID_W is the current per um of fin pitch.

ASAP7 draws every device at L = 20 nm. The default sweep adds 18 nm and
22 nm only so that pygmid can interpolate in L, they are not drawable.

Usage:
    techsweep_asap7.py [--device nmos_rvt] [--corner tt] [--temp 25]
                       [--nfin 1] [--lengths 0.018,0.02,0.022]
                       [--vmax 0.7] [--step 0.01] [--vsb 0,0.1,0.2]
                       [--out asap7_nmos_rvt.pkl]

Needs PDK_ROOT pointing to the PDK installation (default /foss/pdks).
ASAP7 is predictive and not manufacturable.
"""

import argparse
import os
import pickle
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

FIN_PITCH_UM = 0.027
OPVARS = {
    "ID": "ids", "VT": "vth", "GM": "gm", "GMB": "gmbs", "GDS": "gds",
    "CGG": "cgg", "CGS": "cgs", "CGD": "cgd", "CDD": "cdd", "CSS": "css",
}


def run_point(pdk, dev, corner, temp, nfin, length_um, vgs, vds, vsb, workdir):
    """Run one ngspice VGS x VDS sweep at fixed L and VSB, return {key: [vgs, vds]}."""
    pol = -1.0 if dev.startswith("pmos") else 1.0
    inst = "n.xm.n1"
    saves = " ".join(f"@{inst}[{v}]" for v in OPVARS.values())
    out = Path(workdir) / "sweep.txt"
    deck = f"""* ASAP7 techsweep {dev}
.lib {pdk}/libs.tech/ngspice/models/asap7.lib {corner}
.temp {temp}
vd d 0 0
vg g 0 0
vb b 0 {-pol * vsb}
xm d g 0 b {dev} l={length_um}u nfin={nfin}
.control
osdi {pdk}/libs.tech/ngspice/osdi/bsimcmg.osdi
save {saves}
dc vd {pol * vds[0]} {pol * vds[-1]} {pol * (vds[1] - vds[0])} vg {pol * vgs[0]} {pol * vgs[-1]} {pol * (vgs[1] - vgs[0])}
wrdata {out} {saves}
.endc
.end
"""
    deck_path = Path(workdir) / "sweep.sp"
    deck_path.write_text(deck)
    res = subprocess.run(["ngspice", "-b", str(deck_path)], capture_output=True, text=True, cwd=workdir)
    if res.returncode != 0 or not out.exists():
        sys.exit(f"[ERROR] ngspice failed for {dev} L={length_um} VSB={vsb}:\n{res.stdout[-2000:]}{res.stderr[-2000:]}")
    data = np.loadtxt(out)
    # wrdata writes (sweep value, vector value) pairs, one pair per saved vector
    values = data[:, 1::2]
    n_vds, n_vgs = len(vds), len(vgs)
    if values.shape[0] != n_vds * n_vgs:
        sys.exit(f"[ERROR] expected {n_vds * n_vgs} points, got {values.shape[0]}")
    result = {}
    for i, key in enumerate(OPVARS):
        # the inner sweep is vd, the outer vg: rows run VDS fastest
        result[key] = np.abs(values[:, i].reshape(n_vgs, n_vds))
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--device", default="nmos_rvt")
    ap.add_argument("--corner", default="tt")
    ap.add_argument("--temp", type=float, default=25.0)
    ap.add_argument("--nfin", type=int, default=1)
    ap.add_argument("--lengths", default="0.018,0.02,0.022", help="gate lengths in um")
    ap.add_argument("--vmax", type=float, default=0.7)
    ap.add_argument("--step", type=float, default=0.01)
    ap.add_argument("--vsb", default="0,0.1,0.2")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    pdk = Path(os.environ.get("PDK_ROOT", "/foss/pdks")) / "asap7"
    if not (pdk / "libs.tech/ngspice/models/asap7.lib").exists():
        sys.exit(f"[ERROR] ASAP7 models not found below {pdk}")
    lengths = [float(x) for x in args.lengths.split(",")]
    vsbs = [float(x) for x in args.vsb.split(",")]
    vgs = np.round(np.arange(0.0, args.vmax + args.step / 2, args.step), 6)
    vds = vgs.copy()
    out = args.out or f"asap7_{args.device}.pkl"

    shape = (len(lengths), len(vgs), len(vds), len(vsbs))
    table = {key: np.zeros(shape) for key in OPVARS}
    with tempfile.TemporaryDirectory() as tmp:
        for i, length in enumerate(lengths):
            for j, vsb in enumerate(vsbs):
                point = run_point(pdk, args.device, args.corner, args.temp, args.nfin, length, vgs, vds, vsb, tmp)
                for key in OPVARS:
                    table[key][i, :, :, j] = point[key]
                print(f"[INFO] {args.device} L={length} um VSB={vsb} V done")

    table.update({
        "INFO": f"ASAP7 {args.device}, BSIM-CMG 111.2.1 in ngspice, predictive PDK",
        "CORNER": args.corner.upper(),
        "TEMP": args.temp + 273.15,
        "NFING": 1,
        "L": np.array(lengths),
        "W": args.nfin * FIN_PITCH_UM,
        "VGS": vgs,
        "VDS": vds,
        "VSB": np.array(vsbs),
    })
    with open(out, "wb") as f:
        pickle.dump(table, f)
    print(f"[INFO] Wrote {out}")


if __name__ == "__main__":
    main()
