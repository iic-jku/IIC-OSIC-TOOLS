#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""gm/ID lookup tables for the ASAP7 FinFETs, for pygmid.

Sweeps one ASAP7 device in ngspice and writes a .mat file in the layout of
the techsweep tables of the analog-circuit-design course
(https://github.com/iic-jku/analog-circuit-design, gmid/techsweep_sg13_txt_to_mat.ipynb),
so the course notebooks work with it unchanged:

    from pygmid import Lookup as lk
    nmos = lk("asap7_nmos_rvt.mat")
    gm_id = nmos.lookup("GM_ID", VGS=0.4, VDS=0.35)

Fields: INFO, CORNER, TEMP (K), VGS, VDS, VSB (V), L, W (um), NFING, and on
the grid L x VGS x VDS x VSB: ID, VT, GM, GMB, GDS, CGG, CGB, CGD, CGS, CDD,
CSS, STH, SFL. All values are magnitudes, so the PMOS table reads like the
NMOS one, as in the course tables. BSIM-CMG reports the capacitances with
the overlap and fringe parts included. CGB is the gate to substrate
capacitance (BSIM-CMG cge). W is the effective width nfin x 27 nm.

BSIM-CMG has no noise operating-point values, so the noise comes from a
noise analysis of the drain current: STH is the density at 1 GHz (thermal,
flicker is negligible there), SFL the excess over STH at 1 Hz (flicker at
1 Hz), both in A^2/Hz.

The default sweep covers the gate lengths that can be drawn: 20 nm, the
length of ASAP7 and of the model fit, and 24, 28, 36, 60 and 80 nm, which
IIC-OSIC-TOOLS allows for analog design and which are an extrapolation of
the model. pygmid looks up the smallest length, 20 nm, when L is not given.
A .mat table needs at least two lengths (loadmat squeezes a single one to a
scalar, which pygmid cannot use). The 1.8 V IO FinFETs nmos_io18 and
pmos_io18 are swept up to 1.8 V at 80, 160 and 240 nm.

Usage:
    techsweep_asap7.py [--device nmos_rvt] [--corner tt] [--temp 27]
                       [--nfin 1] [--lengths 0.02,0.024,0.028,0.036,0.06,0.08] [--vmax 0.7]
                       [--step 0.025] [--vsb 0,0.1,0.2,0.3] [--out <file>.mat]

Needs PDK_ROOT pointing to the PDK installation (default /foss/pdks).
ASAP7 is predictive and not manufacturable.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy.io import savemat

FIN_PITCH_UM = 0.027
# table field: BSIM-CMG operating-point value
OPVARS = {
    "ID": "ids", "VT": "vth", "GM": "gm", "GMB": "gmbs", "GDS": "gds",
    "CGG": "cgg", "CGB": "cge", "CGD": "cgd", "CGS": "cgs", "CDD": "cdd", "CSS": "css",
}
NOISE_F = (1.0, 1e9)


def run_point(pdk, dev, corner, temp, nfin, length_um, vgs, vds, vsb, workdir):
    """One ngspice run at fixed L and VSB, returns {field: array[vgs, vds]}."""
    pol = -1.0 if dev.startswith("pmos") else 1.0
    inst = "n.xm.n1"
    saves = " ".join(f"@{inst}[{v}]" for v in OPVARS.values())
    op_out = Path(workdir) / "op.txt"
    nz_out = Path(workdir) / "noise.txt"
    for f in (op_out, nz_out):
        f.unlink(missing_ok=True)
    vg_list = " ".join(f"{pol * v:.6g}" for v in vgs)
    vd_list = " ".join(f"{pol * v:.6g}" for v in vds)
    # The drain current reaches the noise output v(n) through a CCVS of 1 Ohm,
    # as in the techsweep testbenches of the course. noise leaves the integrated
# noise plot current, the spectrum is the plot before it.
    deck = f"""* ASAP7 techsweep {dev}
.lib {pdk}/libs.tech/ngspice/models/asap7.lib {corner}
.temp {temp}
vd d 0 0
vg g 0 0 ac 1
vb b 0 {-pol * vsb}
h1 n 0 vd 1
xm d g 0 b {dev} l={length_um}u nfin={nfin}
.control
osdi {pdk}/libs.tech/ngspice/osdi/bsimcmg.osdi
save {saves}
dc vd {pol * vds[0]} {pol * vds[-1]} {pol * (vds[1] - vds[0])} vg {pol * vgs[0]} {pol * vgs[-1]} {pol * (vgs[1] - vgs[0])}
wrdata {op_out} {saves}
destroy all
* drop the save list, it would keep the noise analysis from saving its output
delete all
set appendwrite
foreach vgv {vg_list}
  alter vg dc = $vgv
  foreach vdv {vd_list}
    alter vd dc = $vdv
    noise v(n) vg lin 2 {NOISE_F[0]} {NOISE_F[1]}
    setplot previous
    wrdata {nz_out} onoise_spectrum
    destroy all
  end
end
.endc
.end
"""
    deck_path = Path(workdir) / "sweep.sp"
    deck_path.write_text(deck)
    res = subprocess.run(["ngspice", "-b", str(deck_path)], capture_output=True, text=True, cwd=workdir)
    if res.returncode != 0 or not op_out.exists() or not nz_out.exists():
        sys.exit(f"[ERROR] ngspice failed for {dev} L={length_um} VSB={vsb}:\n{res.stdout[-2000:]}{res.stderr[-2000:]}")
    n_vgs, n_vds = len(vgs), len(vds)

    # wrdata writes (sweep value, vector value) pairs, one pair per vector.
    # The DC sweep runs vd inside vg, so rows run VDS fastest.
    op = np.loadtxt(op_out)[:, 1::2]
    if op.shape[0] != n_vgs * n_vds:
        sys.exit(f"[ERROR] expected {n_vgs * n_vds} operating points, got {op.shape[0]}")
    result = {key: np.abs(op[:, i].reshape(n_vgs, n_vds)) for i, key in enumerate(OPVARS)}

    # onoise_spectrum is the density of v(n) in V/sqrt(Hz), which is the drain
    # current noise in A/sqrt(Hz). Two rows (1 Hz, 1 GHz) per bias point.
    nz = np.loadtxt(nz_out)
    if nz.shape[0] != 2 * n_vgs * n_vds:
        sys.exit(f"[ERROR] expected {2 * n_vgs * n_vds} noise values, got {nz.shape[0]}")
    s = nz[:, 1].reshape(n_vgs, n_vds, 2) ** 2
    result["STH"] = s[:, :, 1]
    result["SFL"] = np.maximum(s[:, :, 0] - s[:, :, 1], 0.0)
    return result


def pdk_info(pdk):
    """Source revisions of the PDK and the ngspice version, for the INFO field."""
    parts = []
    sources = pdk / "SOURCES"
    if sources.exists():
        for line in sources.read_text().splitlines():
            name, _, rev = line.partition(" ")
            if name in ("asap7_pdk_r1p7", "VA-Models"):
                parts.append(f"{name} {rev[:8]}")
    ver = subprocess.run(["ngspice", "-v"], capture_output=True, text=True).stdout
    for line in ver.splitlines():
        if "ngspice-" in line:
            parts.append(line.strip().strip("*").split(":")[0].strip())
            break
    return ", ".join(parts)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--device", default="nmos_rvt")
    ap.add_argument("--corner", default="tt")
    ap.add_argument("--temp", type=float, default=27.0, help="degC, the course tables use 27")
    ap.add_argument("--nfin", type=int, default=1)
    ap.add_argument("--lengths", default=None, help="gate lengths in um, comma-separated, at least two "
                    "(default 0.02,0.024,0.028,0.036,0.06,0.08, for the io18 devices 0.08,0.16,0.24)")
    ap.add_argument("--vmax", type=float, default=None, help="largest VGS and VDS (default 0.7, for the io18 devices 1.8)")
    ap.add_argument("--step", type=float, default=0.025)
    ap.add_argument("--vsb", default="0,0.1,0.2,0.3")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    io = args.device.endswith("_io18")
    if args.lengths is None:
        args.lengths = "0.08,0.16,0.24" if io else "0.02,0.024,0.028,0.036,0.06,0.08"
    if args.vmax is None:
        args.vmax = 1.8 if io else 0.7

    pdk = Path(os.environ.get("PDK_ROOT", "/foss/pdks")) / "asap7"
    if not (pdk / "libs.tech/ngspice/models/asap7.lib").exists():
        sys.exit(f"[ERROR] ASAP7 models not found below {pdk}")
    name = f"asap7_{args.device}"
    out = args.out or f"{name}.mat"
    lengths = sorted(float(x) for x in args.lengths.split(","))
    if len(lengths) < 2:
        sys.exit("[ERROR] --lengths needs at least two lengths, a .mat table cannot hold one")
    vsbs = [float(x) for x in args.vsb.split(",")]
    vgs = np.round(np.arange(0.0, args.vmax + args.step / 2, args.step), 6)
    vds = vgs.copy()

    fields = list(OPVARS) + ["STH", "SFL"]
    shape = (len(lengths), len(vgs), len(vds), len(vsbs))
    table = {key: np.zeros(shape) for key in fields}
    with tempfile.TemporaryDirectory() as tmp:
        for i, length in enumerate(lengths):
            for j, vsb in enumerate(vsbs):
                point = run_point(pdk, args.device, args.corner, args.temp, args.nfin, length, vgs, vds, vsb, tmp)
                for key in fields:
                    table[key][i, :, :, j] = point[key]
                print(f"[INFO] {args.device} L={length} um VSB={vsb} V done")

    dic = {
        "INFO": f"ASAP7 {args.device}, 7nm FinFET predictive (not manufacturable), BSIM-CMG 111.2.1; {pdk_info(pdk)}",
        "CORNER": args.corner.upper(),
        "TEMP": args.temp + 273.15,
        "VGS": vgs,
        "VDS": vds,
        "VSB": np.array(vsbs),
        "L": np.array(lengths),
        "W": args.nfin * FIN_PITCH_UM,
        "NFING": 1,
    }
    dic.update({key: table[key] for key in fields})
    savemat(out, {name: dic})
    print(f"[INFO] Wrote {out}")


if __name__ == "__main__":
    main()
