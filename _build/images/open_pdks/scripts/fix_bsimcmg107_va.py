#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Prepare the BSIM-CMG 107.0.0 Verilog-A for OpenVAF, ngspice and VACASK.

The ASAP7 model cards are written for BSIM-CMG 107. The 107.0.0 source
(CedarEDA/CMC.jl, cmc_models/bsimcmg107) predates the OSDI interface and
needs three edits in bsimcmg_body.include, none of which changes the
currents or charges the model stamps:

* The geometry and variability parameters are model parameters only. OSDI
  simulators set a parameter per instance only if it carries
  (*type="instance"*), so without it ngspice rejects l= and nfin= on the
  device line with "unknown parameter (l)". The attribute is added to the
  instance parameters of BSIM-CMG 111 that 107 already has.
* EOTACC is bounded by [0.1n:inf). OpenVAF evaluates 0.1n to slightly more
  than 1e-10, so eotacc = 1e-10 of the ASAP7 cards is rejected. The bound is
  written as 1e-10.
* The operating-point outputs (GM, GDS, GMBS, the charges and the
  capacitances CGG ... CEE) are computed with ddx() in a block that the
  source has commented out, so ngspice reports them as zero and the pygmid
  lookup tables of ASAP7 come out empty. The comment around the block is
  removed. VTH, IDS and the other currents are outside it and already set.

The script fails if a declaration is not found exactly once, which means the
pinned source changed and this script needs a look. It is idempotent.

Usage: fix_bsimcmg107_va.py <bsimcmg_body.include>
"""

import re
import sys
from pathlib import Path

INSTANCE = (
    "L D TFIN FPITCH NF NFIN NGCON ASEO ADEO PSEO PDEO ASEJ ADEJ PSEJ PDEJ "
    "COVS COVD CGSP CGDP CDSP NRS NRD LRSD DTEMP DELVTRAND U0MULT"
).split()
ATTR = '(*type="instance"*) '


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = Path(sys.argv[1])
    text = path.read_text()
    for name in INSTANCE:
        decl = re.compile(rf'^(\(\*type="instance"\*\) )?(parameter\s+(real|integer)\s+{name}\s*=)', re.MULTILINE)
        found = decl.findall(text)
        if len(found) != 1:
            sys.exit(f"[ERROR] {path}: expected one declaration of {name}, found {len(found)}")
        text = decl.sub(ATTR + r"\2", text)
    eotacc = re.compile(r"^(parameter\s+real\s+EOTACC\s*=\s*EOT\s+from\s+\[)(0\.1n|1e-10)(:inf\);)", re.MULTILINE)
    if len(eotacc.findall(text)) != 1:
        sys.exit(f"[ERROR] {path}: expected one declaration of EOTACC with the bound 0.1n")
    text = eotacc.sub(r"\g<1>1e-10\3", text)
    opinfo_start = re.compile(r"^\t\t/\*\n(?=\t\t// Conductances\n)", re.MULTILINE)
    opinfo_end = re.compile(r"^\t\t\*/\n(?=\t`endif // __OPINFO__\n)", re.MULTILINE)
    starts, ends = len(opinfo_start.findall(text)), len(opinfo_end.findall(text))
    if (starts, ends) not in ((1, 1), (0, 0)) or (starts == 0 and "\t\t// Conductances\n\t\tGM " not in text):
        sys.exit(f"[ERROR] {path}: the commented-out operating-point block was not found")
    text = opinfo_end.sub("", opinfo_start.sub("", text))
    path.write_text(text)
    print(f"[INFO] Patched {path}: {len(INSTANCE)} instance parameters, EOTACC bound, operating-point outputs.")


if __name__ == "__main__":
    main()
