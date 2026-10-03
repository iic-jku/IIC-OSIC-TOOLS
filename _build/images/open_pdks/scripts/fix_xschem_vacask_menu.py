#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Add corner files to the "Add VACASK models symbol" entry of the IHP xschem menu.

VACASK's converters write libs.tech/xschem/xschem-vacask, whose IHP menu entry
"Add VACASK models symbol" places a simulator-commands symbol that includes the
common file and one section per corner file:

    include \\"cornerMOSlv.lib\\" section=mos_tt
    ...
    include \\"cornerCAP.lib\\" section=cap_typ

The list is fixed in the converters and covers MOSlv, MOShv, HBT (SG13G2 only),
RES and CAP. A design using another device -- a diode, the pnpMPA of CMOS5L,
the MOS capacitor -- gets no corner section for it and has to add the include
by hand, although its corner file is converted. This adds the given corner
files, each with the given (typical) section, after the last corner include of
the symbol. It is a local addition, not a fix.

A corner is only added if its converted file exists and has that section, since
a dangling include would break every deck the symbol is placed in, and if it is
not listed yet, so this is idempotent and a no-op once upstream lists it. If the
corner list cannot be found the menu is left as it is, with a warning: it is a
convenience and not worth failing the build over.

usage: fix_xschem_vacask_menu.py <pdk_dir> <corner.lib>=<section> ...
"""

import os
import re
import sys

CORNER = re.compile(r'^include \\"(corner[^"\\]+)\\" section=\S+\n', re.MULTILINE)


def main() -> int:
    if len(sys.argv) < 3 or not all("=" in arg for arg in sys.argv[2:]):
        print("usage: %s <pdk_dir> <corner.lib>=<section> ..." % sys.argv[0],
              file=sys.stderr)
        return 2
    pdk_dir = sys.argv[1]
    path = os.path.join(pdk_dir, "libs.tech", "xschem", "xschem-vacask")
    models = os.path.join(pdk_dir, "libs.tech", "vacask", "models")

    with open(path, 'r') as f:
        tcl = f.read()

    listed = list(CORNER.finditer(tcl))
    if not listed:
        print("[WARN] No corner include found in %s, corner list left as is "
              "(upstream changed the menu?)" % path)
        return 0
    names = {match.group(1) for match in listed}

    added = []
    for arg in sys.argv[2:]:
        corner, section = arg.split("=", 1)
        if corner in names:
            continue
        source = os.path.join(models, corner)
        if not os.path.isfile(source):
            print("[WARN] %s was not converted for VACASK, not added to the menu."
                  % corner)
            continue
        with open(source, 'r') as f:
            if not re.search(r'^section\s+%s\s*$' % re.escape(section), f.read(),
                             re.MULTILINE):
                print("[WARN] %s has no section %s, not added to the menu."
                      % (corner, section))
                continue
        added.append((corner, section))

    if not added:
        print("[INFO] The xschem VACASK menu already lists every requested corner.")
        return 0

    end = listed[-1].end()
    tcl = tcl[:end] + "".join('include \\"%s\\" section=%s\n' % item
                              for item in added) + tcl[end:]
    with open(path, 'w') as f:
        f.write(tcl)
    for corner, section in added:
        print("[INFO] Added %s section=%s to the xschem VACASK menu." % (corner, section))
    return 0


if __name__ == "__main__":
    sys.exit(main())
