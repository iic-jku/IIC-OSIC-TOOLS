#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Keep the global SWSOA parameter out of the VACASK model files of the IHP PDKs.

The ngspice MOS model files of the IHP PDKs switch the safe-operating-area
checks of PSP103 off with a global

    .param SWSOA = 0

which their model cards read back as swsoa=swsoa. VACASK's converters
(sg13g2tovc.py and sg13cmos5ltovc.py) define that parameter once, in the
generated <pdk>_vacask_common.lib, and drop the line from each model file
through their "patches" table:

    "sg13g2_moshv_mod.lib": [ ( ".param SWSOA = 0", "" ) ],

The table names the files one by one, and the MOS capacitor is missing from
it: IHP added sg13g2_moscap_mod.lib and sg13g2_moscap_mod_mismatch.lib on
2026-07-22 (IHP-Open-PDK 5d78a6d6), both carrying the same line. Converted, it
becomes a second "parameters swsoa=0" next to the one in the common include,
and VACASK rejects every deck that loads a cornerMOSCAP.lib section with

    Parameter redefinition.

So every model file in the converter's tech_files whose PDK source sets SWSOA
this way, and that has no entry of its own in "patches" yet, gets the entry
upstream gives the MOS files. ng2vclib matches a patch by the end of the file
name and the start of the line (ng2vclib/m_file.py), so the line is copied
verbatim from the PDK source. The next model file with that line is covered
without a change here. This is a no-op once VACASK catches up, and it is
idempotent. If tech_files or patches cannot be found the patch fails instead
of silently doing nothing: that means upstream restructured the converter and
this helper needs a look.

Shared by install_ihp.sh and install_ihp_cmos5l.sh; it has to run after the
PDK-specific helper, which may add model files to tech_files.
"""

import os
import re
import sys

ENTRY = re.compile(r'^\s*\(\s*"([^"]+\.lib)"', re.MULTILINE)
SWSOA = re.compile(r'^\.param\s+SWSOA\b.*$', re.MULTILINE | re.IGNORECASE)


def span(content: str, name: str, opening: str, closing: str) -> tuple:
    """Return (start, end) offsets of the body of `name = <opening> ... <closing>`.

    The converters write the closing bracket of their top-level tables in the
    first column, which is all this relies on.
    """
    start = re.search(r'^%s\s*=\s*%s' % (name, re.escape(opening)), content, re.MULTILINE)
    if start is None:
        return None
    end = re.search(r'^%s' % re.escape(closing), content[start.end():], re.MULTILINE)
    if end is None:
        return None
    return start.end(), start.end() + end.start()


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: %s <converter.py> <pdk_dir>" % sys.argv[0], file=sys.stderr)
        return 2
    converter, pdk_dir = sys.argv[1], sys.argv[2]
    models_dir = os.path.join(pdk_dir, "libs.tech", "ngspice", "models")

    with open(converter, 'r') as f:
        content = f.read()

    tech_span = span(content, "tech_files", "[", "]")
    patch_span = span(content, "patches", "{", "}")
    if tech_span is None or patch_span is None:
        print("[ERROR] tech_files and/or patches not found in %s." % converter,
              file=sys.stderr)
        print("[ERROR] The VACASK converter was restructured; "
              "fix_vacask_swsoa.py needs updating.", file=sys.stderr)
        return 1

    patches = content[patch_span[0]:patch_span[1]]
    additions = []
    for name in ENTRY.findall(content[tech_span[0]:tech_span[1]]):
        source = os.path.join(models_dir, name)
        if not os.path.isfile(source):
            continue
        if re.search(r'^\s*"%s"\s*:' % re.escape(name), patches, re.MULTILINE):
            continue
        with open(source, 'r', errors='replace') as f:
            match = SWSOA.search(f.read())
        if match is None:
            continue
        additions.append((name, match.group(0).rstrip()))

    if not additions:
        print("[INFO] No model file of the VACASK converter sets SWSOA unpatched, "
              "nothing to add.")
        return 0

    # Insert at the top of the table, where "entry," is valid whatever the last
    # entry upstream ends with.
    text = "\n    # Added by fix_vacask_swsoa.py\n" + "".join(
        '    "%s": [\n        (\n            "%s", \n            ""\n        )\n    ], \n'
        % (name, line.replace('\\', '\\\\').replace('"', '\\"'))
        for name, line in additions)
    content = content[:patch_span[0]] + text + content[patch_span[0]:]

    with open(converter, 'w') as f:
        f.write(content)
    for name, line in additions:
        print("[INFO] The VACASK converter now drops '%s' from %s." % (line, name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
