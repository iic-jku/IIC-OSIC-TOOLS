#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Teach VACASK's sg13g2tovc.py about the SG13G2 Verilog-A devices it misses.

The converter compiles the Verilog-A models named in a hardcoded list:

    included_va_files = [
        ( "r3_cmc/r3_cmc.va",     [ "-D__NGSPICE" ] ),
        ...
    ]

and writes a "load" line for each into sg13g2_vacask_common.lib. The SG13G2
PDK is installed from the tip of the IHP dev branch (see install_ihp.sh) and
gained two Verilog-A devices that VACASK does not list: the MoM capacitors
cap_cmomi (IHP-Open-PDK 9afbfadc, 2026-07-30) and cap_cmomf (4bff57a2,
2026-08-11). capacitors_mod.lib includes their wrapper .lib files, so the
converted models define "model cap_cmomi_mod cap_cmomi", but the device is
never compiled nor loaded, and every VACASK deck instantiating either
capacitor fails on that model line.

cap_cmomi has a second problem: its wrapper writes a subckt default
symbolically (".param none=0 same=1 double=2" plus "feed=double" on the
.subckt line). VACASK treats such a parameter as derived and rejects every
override with "Parameter 'feed' not found.". The CMOS5L converter patches
that line by hand in its "patches" table, sg13g2tovc.py does not.

This helper derives both fixes from the PDK instead of naming the devices:

- every Verilog-A module <name>/<name>.va under libs.tech/verilog-a that
  included_va_files lacks is appended with the options of the existing entries.
- for each such module whose wrapper libs.tech/ngspice/models/<name>.lib has a
  .subckt default naming a .param constant, a "patches" entry replaces the
  .subckt line with one carrying the literal value. ng2vclib applies patches
  per file at read time, so this also covers the wrapper when it is pulled in
  by an include.

Entries already present are left alone, so this is a no-op once VACASK catches
up, and it is idempotent. If either list cannot be found the helper fails
instead of silently doing nothing: that means upstream restructured the
converter and this helper needs a look. Regression test 36 instantiates both
capacitors in VACASK.
"""

import os
import re
import sys

VA_OPTIONS = '[ "-D__NGSPICE" ]'
VA_ENTRY = re.compile(r'^\s*\(\s*"([^"]+\.va)"', re.MULTILINE)
PATCH_KEY = re.compile(r'^\s*"([^"]+)"\s*:', re.MULTILINE)
PARAM = re.compile(r'^\s*\.param\s+(.*)$', re.IGNORECASE)
ASSIGN = re.compile(r'(\w+)\s*=\s*([^\s=]+)')
NUMBER = re.compile(r'^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$')


def span(content: str, name: str, opening: str, closing: str) -> tuple:
    """Return (start, end) offsets of the body of `name = <opening> ... <closing>`.

    The converter closes its top-level lists and dicts in the first column,
    which is all this relies on.
    """
    start = re.search(r'^%s\s*=\s*\%s' % (re.escape(name), opening), content, re.MULTILINE)
    if start is None:
        return None
    end = re.search(r'^\%s' % closing, content[start.end():], re.MULTILINE)
    if end is None:
        return None
    return start.end(), start.end() + end.start()


def own_va_modules(va_dir: str) -> list:
    """Verilog-A modules of the PDK, as paths relative to libs.tech/verilog-a."""
    modules = []
    for entry in sorted(os.listdir(va_dir)):
        if os.path.isfile(os.path.join(va_dir, entry, entry + ".va")):
            modules.append(entry + "/" + entry + ".va")
    return modules


def literal_subckt(lib: str) -> tuple:
    """Return (old, new) .subckt line with .param constants as literals, or None."""
    with open(lib, 'r', errors='replace') as f:
        lines = [line.rstrip('\r\n') for line in f]
    constants = {}
    for line in lines:
        match = PARAM.match(line)
        if match is None:
            continue
        for key, value in ASSIGN.findall(match.group(1)):
            if NUMBER.match(value):
                constants[key.lower()] = value
    for index, line in enumerate(lines):
        if not line.lstrip().lower().startswith(".subckt"):
            continue
        if index + 1 < len(lines) and lines[index + 1].lstrip().startswith("+"):
            print("[WARNING] %s continues its .subckt line, not checked for symbolic "
                  "defaults." % lib, file=sys.stderr)
            return None
        new = ASSIGN.sub(lambda m: "%s=%s" % (m.group(1), constants.get(m.group(2).lower(), m.group(2))),
                         line)
        return (line, new) if new != line else None
    return None


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: %s <sg13g2tovc.py> <pdk_dir>" % sys.argv[0], file=sys.stderr)
        return 2
    converter, pdk_dir = sys.argv[1], sys.argv[2]
    va_dir = os.path.join(pdk_dir, "libs.tech", "verilog-a")
    models_dir = os.path.join(pdk_dir, "libs.tech", "ngspice", "models")

    with open(converter, 'r') as f:
        content = f.read()
    va_span = span(content, "included_va_files", "[", "]")
    patch_span = span(content, "patches", "{", "}")
    if va_span is None or patch_span is None:
        print("[ERROR] included_va_files or patches not found in %s." % converter,
              file=sys.stderr)
        print("[ERROR] The VACASK converter was restructured; "
              "fix_sg13g2_vacask_va.py needs updating.", file=sys.stderr)
        return 1

    listed = set(VA_ENTRY.findall(content[va_span[0]:va_span[1]]))
    added = [module for module in own_va_modules(va_dir) if module not in listed]
    if not added:
        print("[INFO] The VACASK converter compiles every Verilog-A model of the PDK, "
              "nothing to change.")
        return 0

    patched = set(PATCH_KEY.findall(content[patch_span[0]:patch_span[1]]))
    patches = []
    for module in added:
        lib = os.path.basename(module)[:-3] + ".lib"
        if lib in patched or not os.path.isfile(os.path.join(models_dir, lib)):
            continue
        change = literal_subckt(os.path.join(models_dir, lib))
        if change is not None:
            patches.append((lib, change))

    va_text = ("    # Added by fix_sg13g2_vacask_va.py\n"
               + "".join('    ( "%s", %s ), \n' % (module, VA_OPTIONS) for module in added))
    patch_text = "".join('    # Added by fix_sg13g2_vacask_va.py\n    %r: [\n        (\n'
                         '            %r, \n            %r\n        )\n    ], \n'
                         % (lib, old, new) for lib, (old, new) in patches)
    # Insert back to front, so the earlier offset stays valid.
    for offset, text in sorted([(va_span[1], va_text), (patch_span[1], patch_text)],
                               reverse=True):
        content = content[:offset] + text + content[offset:]
    with open(converter, 'w') as f:
        f.write(content)
    for module in added:
        print("[INFO] Added %s to the VACASK converter (Verilog-A model of the PDK)."
              % module)
    for lib, (old, new) in patches:
        print("[INFO] Made the subckt defaults of %s literal: %s" % (lib, new.strip()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
