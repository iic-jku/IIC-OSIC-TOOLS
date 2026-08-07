#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Patch an IHP KLayout netlist import template file in place.

Both IHP PDKs ship ihp130_pcell_templates.py, and SG13CMOS5L carries its own
copy rather than a symlink into SG13G2, so the same two fixes have to be applied
to each of them:

1. Make ``m=`` optional in the device regexes. xschem omits ``m=1`` when the
   multiplicity equals the default of 1, but the templates require it.
2. Accept ``nf=`` as an alternative to ``ng=`` for the MOSFET finger count,
   which some xschem symbol versions emit instead.

The rewrite is idempotent, so re-running it on an already patched file is a
no-op.
"""

import sys


def patch(content: str) -> str:
    # 1. Make m= optional in all regex patterns that currently require it.
    #    Use a placeholder to protect patterns that are already optional.
    old = r'(?=.*m=(?P<m>\d+))'
    new = r'(?:(?=.*m=(?P<m>\d+))|)'
    placeholder = '___OPTIONAL_M___'
    content = content.replace(new, placeholder)
    content = content.replace(old, new)
    content = content.replace(placeholder, new)
    # 2. Accept both ng= and nf= for MOSFET finger count
    #    (xschem may generate nf= in some symbol versions instead of ng=)
    content = content.replace(
        r'(?=.*ng=(?P<ng>\d+))',
        r'(?=.*(?:ng|nf)=(?P<ng>\d+))'
    )
    return content


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <ihp130_pcell_templates.py>", file=sys.stderr)
        return 2
    fname = sys.argv[1]
    with open(fname, 'r') as f:
        content = f.read()
    patched = patch(content)
    if patched == content:
        print(f"[INFO] KLayout netlist import templates already up to date in {fname}")
        return 0
    with open(fname, 'w') as f:
        f.write(patched)
    print(f"[INFO] Fixed KLayout netlist import templates in {fname}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
