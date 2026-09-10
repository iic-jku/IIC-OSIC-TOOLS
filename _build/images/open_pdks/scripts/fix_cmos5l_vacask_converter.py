#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Teach VACASK's sg13cmos5ltovc.py about the CMOS5L-own OSDI devices it misses.

VACASK ships the CMOS5L -> VACASK converter as python/sg13cmos5ltovc.py, and it
names the devices it converts in two hardcoded lists:

    tech_files = [
        ( "cap_cmomi.lib", 0, 0 ),
        ...
    ]
    included_va_files = [
        ( "cap_cmomi/cap_cmomi.va",     [ "-D__NGSPICE" ] ),
    ]

The CMOS5L PDK is installed from its default branch rather than from a pinned
commit (see install_ihp_cmos5l.sh), so it grows devices between VACASK releases.
When it does, the converted PDK breaks in a way that is easy to miss: the model
wrapper .lib is never converted and its Verilog-A is never compiled, yet the
corner file that includes it *is* converted verbatim. Every VACASK deck that
pulls in that corner then dies on a missing include, even one that does not use
the new device at all.

That is exactly what cap_cmomf, the metal fringe MoM capacitor added to the PDK
on 2026-08-11, did to the whole CMOS5L capacitor path: cornerCAP.lib gained an
".include cap_cmomf.lib" in every one of its sections, so a deck as small as

    include "cornerCAP.lib" section=cap_typ

no longer loads (regression test 29).

Rather than pin the device name, this patch derives it from the PDK: every
CMOS5L-own Verilog-A module (a real directory <name>/<name>.va under
libs.tech/verilog-a -- psp103, r3_cmc and mosvar are symlinks into SG13G2 and
are handled by the converter's osdi_symlinks) is added to included_va_files, and its
ngspice wrapper libs.tech/ngspice/models/<name>.lib, if there is one, to
tech_files. The next device the PDK adds is therefore covered without a change
here.

Devices the converter already lists are left alone, so this is a no-op once
VACASK catches up, and it is idempotent. If either list cannot be found the
patch fails instead of silently doing nothing: that means upstream restructured
the converter and this helper needs a look.

Note what this deliberately does NOT do: a new device whose .lib writes its
subckt defaults symbolically (".param none=0 same=1 double=2" plus "feed=double"
on the .subckt line, the way cap_cmomi does) is still locked to its default in
VACASK, which treats such a parameter as derived and rejects every override.
Upstream patches that one case by hand in sg13cmos5ltovc.py's "patches" table.
cap_cmomf has literal defaults and needs nothing; test 29 is the guard if a
future device does not.
"""

import os
import re
import sys

# Passed to OpenVAF for the generated included_va_files entries. Mirrors the
# converter's own cap_cmomi entry. Both CMOS5L Verilog-A sources only test
# __XYCE__, so the define is inert -- it is kept for consistency with the
# neighbouring entry rather than for effect.
VA_OPTIONS = '[ "-D__NGSPICE" ]'


def find_list(content: str, name: str) -> tuple:
    """Return (start, end) offsets of the bracketed body of `name = [ ... ]`.

    Offsets point just after the opening bracket and at the closing one. The
    scan tracks nesting and skips quoted text and comments, because
    included_va_files holds a nested list of OpenVAF options.
    """
    match = re.search(r'^%s\s*=\s*\[' % re.escape(name), content, re.MULTILINE)
    if match is None:
        return None
    start = match.end()
    depth = 1
    i = start
    quote = None
    while i < len(content):
        char = content[i]
        if quote is not None:
            if char == '\\':
                i += 2
                continue
            if char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == '#':
            end_of_line = content.find('\n', i)
            i = len(content) if end_of_line < 0 else end_of_line
            continue
        elif char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
            if depth == 0:
                return start, i
        i += 1
    return None


def own_va_modules(pdk_dir: str) -> list:
    """CMOS5L-own Verilog-A modules, i.e. <name>/<name>.va that is not a symlink."""
    va_dir = os.path.join(pdk_dir, "libs.tech", "verilog-a")
    modules = []
    for entry in sorted(os.listdir(va_dir)):
        path = os.path.join(va_dir, entry)
        # psp103, r3_cmc and mosvar are symlinks into SG13G2; the converter
        # symlinks their VACASK OSDI objects in instead of recompiling them.
        if os.path.islink(path) or not os.path.isdir(path):
            continue
        if os.path.isfile(os.path.join(path, entry + ".va")):
            modules.append(entry)
    return modules


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: %s <sg13cmos5ltovc.py> <pdk_dir>" % sys.argv[0],
              file=sys.stderr)
        return 2
    converter, pdk_dir = sys.argv[1], sys.argv[2]

    with open(converter, 'r') as f:
        content = f.read()

    tech_span = find_list(content, "tech_files")
    va_span = find_list(content, "included_va_files")
    if tech_span is None or va_span is None:
        print("[ERROR] tech_files and/or included_va_files not found in %s."
              % converter, file=sys.stderr)
        print("[ERROR] The VACASK converter was restructured; "
              "fix_cmos5l_vacask_converter.py needs updating.", file=sys.stderr)
        return 1

    modules = own_va_modules(pdk_dir)
    if not modules:
        print("[ERROR] No CMOS5L-own Verilog-A module found under %s."
              % os.path.join(pdk_dir, "libs.tech", "verilog-a"), file=sys.stderr)
        return 1
    print("[INFO] CMOS5L-own Verilog-A modules: %s" % ", ".join(modules))

    tech_body = content[tech_span[0]:tech_span[1]]
    va_body = content[va_span[0]:va_span[1]]
    new_tech, new_va = [], []

    for name in modules:
        if not re.search(r'"%s/%s\.va"' % (re.escape(name), re.escape(name)), va_body):
            new_va.append('    ( "%s/%s.va", %s ), \n' % (name, name, VA_OPTIONS))
        wrapper = os.path.join(pdk_dir, "libs.tech", "ngspice", "models", name + ".lib")
        if os.path.isfile(wrapper) and not re.search(r'"%s\.lib"' % re.escape(name), tech_body):
            new_tech.append('    ( "%s.lib", 0, 0 ), \n' % name)

    if not new_tech and not new_va:
        print("[INFO] The VACASK converter already covers every CMOS5L-own "
              "device, nothing to add.")
        return 0

    # Append to each list body, later span first so the earlier offsets hold.
    for span, additions in sorted(((tech_span, new_tech), (va_span, new_va)),
                                  key=lambda item: item[0][1], reverse=True):
        if additions:
            content = (content[:span[1]]
                       + "    # Added by fix_cmos5l_vacask_converter.py\n"
                       + "".join(additions)
                       + content[span[1]:])

    with open(converter, 'w') as f:
        f.write(content)

    for line in new_tech + new_va:
        print("[INFO] Added to the VACASK converter: %s" % line.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
