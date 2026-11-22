#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Align the ASAP7 standard-cell CDL with the LEF, so designs can be netlisted.

OpenROAD's write_cdl takes the pin order of every placed cell from the CDL
masters and looks the pins up by their LEF names. Against the asap7sc7p5t_28
CDL (asap7sc7p5t_28 e5bd25d) that fails twice:

* FILLER, FILLERxp5, TAPCELL and TAPCELL_WITH_FILLER have a LEF macro and a
  layout but no subcircuit, so write_cdl stops at the first tap cell
  (ODB-0287). They are added as empty subcircuits with the LEF pins VDD VSS.
* DFFASRHQNx1 names its set and reset pins RESETn and SETn, the LEF and the
  Liberty RESETN and SETN, so write_cdl leaves them unconnected (ODB-0286).
  They are renamed in the subcircuit.

Usage: fix_asap7_cdl.py <cdl-file> <vt-suffix>  (vt-suffix: R, L, SL or SRAM)
"""

import re
import sys
from pathlib import Path

RENAMES = {"RESETn": "RESETN", "SETn": "SETN"}
EMPTY_CELLS = ["FILLER", "FILLERxp5", "TAPCELL", "TAPCELL_WITH_FILLER"]


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    path = Path(sys.argv[1])
    vt = sys.argv[2]
    lines = path.read_text().splitlines()

    dff = f"DFFASRHQNx1_ASAP7_75t_{vt}"
    inside = False
    renamed = 0
    out = []
    for line in lines:
        if re.match(rf"\.SUBCKT\s+{dff}\s", line, re.I):
            inside = True
        if inside:
            for old, new in RENAMES.items():
                line, n = re.subn(rf"(?<![A-Za-z0-9_]){old}(?![A-Za-z0-9_])", new, line)
                renamed += n
        if inside and re.match(r"\.ENDS", line, re.I):
            inside = False
        out.append(line)
    if renamed == 0:
        sys.exit(f"[ERROR] {path}: no RESETn/SETn found in {dff}, the CDL changed upstream")

    names = {l.split()[1].upper() for l in out if l.upper().startswith(".SUBCKT")}
    added = []
    for cell in EMPTY_CELLS:
        name = f"{cell}_ASAP7_75t_{vt}"
        if name.upper() in names:
            continue
        out += ["", f".SUBCKT {name} VDD VSS", ".ENDS"]
        added.append(name)

    path.write_text("\n".join(out) + "\n")
    print(f"[INFO] {path.name}: renamed {renamed} RESETn/SETn in {dff}, added {', '.join(added) or 'nothing'}.")


if __name__ == "__main__":
    main()
