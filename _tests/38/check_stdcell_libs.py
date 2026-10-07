# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run inside KLayout (klayout -zz -r) after sak-pdk-script.sh has set up the PDK.
# The IHP PDKs register their standard cells as KLayout libraries through
# autorun macros in libs.tech/klayout/tech/pymacros. Checks that both the LV
# and the HV library of the active PDK are registered and contain an inverter.
# Exits 1 on a missing library or cell.

import os
import sys

import pya

# Library name -> a cell it must contain. CMOS5L's HV library reuses the
# SG13G2 HV cells, so its cells keep the sg13g2_hv_ prefix.
EXPECTED = {
    "ihp-sg13g2": {
        "sg13g2_stdcell": "sg13g2_inv_1",
        "sg13g2_stdcell_hv": "sg13g2_hv_inv_1",
    },
    "ihp-sg13cmos5l": {
        "sg13cmos5l_stdcell": "sg13cmos5l_inv_1",
        "sg13cmos5l_stdcell_hv": "sg13g2_hv_inv_1",
    },
}

pdk = os.environ.get("PDK", "")
if pdk not in EXPECTED:
    print(f"[ERROR] No expected libraries for PDK <{pdk}>.")
    sys.exit(1)

error = 0
for lib_name, cell_name in EXPECTED[pdk].items():
    lib = pya.Library.library_by_name(lib_name)
    if lib is None:
        print(f"[ERROR] {pdk}: library <{lib_name}> is not registered.")
        error = 1
        continue
    layout = lib.layout()
    if layout.cell(cell_name) is None:
        print(f"[ERROR] {pdk}: library <{lib_name}> has no cell <{cell_name}>.")
        error = 1
        continue
    print(f"[INFO] {pdk}: library <{lib_name}> registered with {layout.cells()} cells.")

sys.exit(error)
