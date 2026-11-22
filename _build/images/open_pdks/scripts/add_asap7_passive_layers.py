#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Add the passive device layers to the KLayout layer properties of ASAP7.

asap7.lyp comes from ASAP7_for_KLayout and knows the ASAP7 layers only. The
layers that IIC-OSIC-TOOLS adds for passive devices are appended: the
resistor markers RES_M1 to RES_M9 (120/1 to 120/9), the thin-film resistor
TFR (121/0), the capacitor marker MOMCAP (122/0) and the thick gate oxide
TG of the IO FinFETs (123/0) and the markers DIODE (124/0) and BJT (125/0)
of the junction devices.

Usage: add_asap7_passive_layers.py <asap7.lyp>
"""

import sys
from pathlib import Path

ENTRY = """  <properties>
   <frame-color>{color}</frame-color>
   <fill-color>{color}</fill-color>
   <frame-brightness>0</frame-brightness>
   <fill-brightness>0</fill-brightness>
   <dither-pattern>{pattern}</dither-pattern>
   <line-style/>
   <valid>true</valid>
   <visible>true</visible>
   <transparent>false</transparent>
   <width>1</width>
   <marked>false</marked>
   <xfill>false</xfill>
   <animation>0</animation>
   <name>{name} - {layer}/{datatype}</name>
   <source>{layer}/{datatype}@1</source>
  </properties>
"""
# I1 is the hollow pattern, used for the markers
LAYERS = [(f"RES_M{n}", 120, n, "#ff8000", "I1") for n in range(1, 10)]
LAYERS += [("TFR", 121, 0, "#008050", "I5"), ("MOMCAP", 122, 0, "#8000ff", "I1"), ("TG", 123, 0, "#c04000", "I1")]
LAYERS += [("DIODE", 124, 0, "#0080c0", "I1"), ("BJT", 125, 0, "#c00080", "I1")]
# The entries go after the last layer of the file
ANCHOR = "  </properties>\n"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = Path(sys.argv[1])
    text = path.read_text()
    pos = text.rfind(ANCHOR)
    if pos < 0:
        sys.exit(f"[ERROR] {path}: no layer entry to insert the layers after")
    pos += len(ANCHOR)
    for _, layer, datatype, _, _ in LAYERS:
        if f"<source>{layer}/{datatype}@" in text:
            sys.exit(f"[ERROR] {path}: layer {layer}/{datatype} is already defined")
    entries = "".join(
        ENTRY.format(name=n, layer=la, datatype=d, color=c, pattern=p) for n, la, d, c, p in LAYERS
    )
    path.write_text(text[:pos] + entries + text[pos:])
    print(f"[INFO] Added {len(LAYERS)} passive device layers to {path}.")


if __name__ == "__main__":
    main()
