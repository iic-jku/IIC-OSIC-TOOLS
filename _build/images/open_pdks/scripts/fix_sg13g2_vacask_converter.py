#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Reconcile VACASK's sg13g2tovc.py model file list with the installed SG13G2 PDK.

VACASK's SG13G2 -> VACASK converter, python/sg13g2tovc.py, names the ngspice
model files it converts in a hardcoded list:

    tech_files = [
        ( "capacitors_mod.lib", 1, None ),
        ...
        ( "cornerCAP.lib", 0, 0 ),
        ...
    ]

The SG13G2 PDK is installed from the tip of the IHP dev branch rather than from
a pinned commit (see install_ihp.sh), so the two drift apart, in both
directions:

- The PDK drops a model file the list still names. The converter then dies on
  the stale entry with

      ng2vclib.exc.ConverterError: File sg13g2_hbt_mod_mismatch.lib not found

  and takes the whole VACASK preparation, and with it the image build, down.
  That is what happened when IHP folded the HBT mismatch models into
  sg13g2_hbt_mod.lib on 2026-09-17 (IHP-Open-PDK 7b10545e). Such an entry is
  commented out -- but only when no model file of the PDK still includes it,
  otherwise this fails, as the conversion would be incomplete anyway.

- A corner file includes a model file the list does not name. The corner files
  are converted verbatim (output depth 0), includes and all, so the converted
  corner then refers to a file that is never produced, and VACASK aborts with
  "File not found." on every deck using that section. That is the state
  cornerDIO.lib has been in since the Schottky diode arrived on 2025-09-10
  (IHP-Open-PDK 5013fe8a): its dio_tt_stat section includes
  sg13g2_dschottky_nbl1_stat.lib. Such a file is added to the list with the
  same depths as its siblings (read one level, output flattened).

- The PDK ships a corner file the list does not name, i.e. a whole device
  that never reaches VACASK. That is the MOS capacitor, added on 2026-07-22
  (IHP-Open-PDK 5d78a6d6) with cornerMOSCAP.lib; the CMOS5L converter lists
  it, sg13g2tovc.py does not. Such a corner file is added verbatim like the
  others, and the model files it includes then follow by the rule above.
  MOSCAP needs no new Verilog-A, it is PSP103 like the MOS transistors. A
  future device that does would fail the conversion, which is preferred to
  shipping without it.

The standard-cell and I/O netlist entries are left alone. MOSCAP also needs
fix_vacask_swsoa.py, which install_ihp.sh runs right after this helper. This is a no-op once
VACASK catches up, and it is idempotent. If tech_files cannot be found the
patch fails instead of silently doing nothing: that means upstream restructured
the converter and this helper needs a look. install_ihp.sh checks after the
conversion that every include of the converted models resolves.
"""

import os
import re
import sys

ENTRY = re.compile(r'^(\s*)\(\s*"([^"]+\.lib)"', re.MULTILINE)
# Entries converted verbatim, i.e. with an output depth of 0 (the corner files)
VERBATIM = re.compile(r'^\s*\(\s*"([^"]+\.lib)"\s*,\s*\d+\s*,\s*0\s*\)', re.MULTILINE)
INCLUDE = re.compile(r'^\s*\.include\s+"?([^"\s]+)"?', re.MULTILINE | re.IGNORECASE)


def tech_files_span(content: str) -> tuple:
    """Return (start, end) offsets of the body of `tech_files = [ ... ]`.

    The converter writes one entry per line and closes the list with a "]" in
    the first column, which is all this relies on.
    """
    start = re.search(r'^tech_files\s*=\s*\[', content, re.MULTILINE)
    if start is None:
        return None
    end = re.search(r'^\]', content[start.end():], re.MULTILINE)
    if end is None:
        return None
    return start.end(), start.end() + end.start()


def read(path: str) -> str:
    with open(path, 'r', errors='replace') as f:
        return f.read()


def included_by(models_dir: str, name: str) -> list:
    """Model files in models_dir that still .include (or .lib) `name`."""
    pattern = re.compile(r'^\s*\.(?:include|inc|lib)\s+"?%s"?(\s|$)' % re.escape(name),
                         re.MULTILINE | re.IGNORECASE)
    return [entry for entry in sorted(os.listdir(models_dir))
            if os.path.isfile(os.path.join(models_dir, entry))
            and pattern.search(read(os.path.join(models_dir, entry)))]


def drop_stale(body: str, models_dir: str) -> tuple:
    """Comment out the .lib entries the PDK no longer ships.

    Returns the updated body and the dropped names, or None for the body if a
    dropped file is still included by the PDK.
    """
    dropped = []
    # Back to front, so the offsets of the entries still to come stay valid.
    for match in reversed(list(ENTRY.finditer(body))):
        name = match.group(2)
        if os.path.isfile(os.path.join(models_dir, name)):
            continue
        users = included_by(models_dir, name)
        if users:
            print("[ERROR] %s is listed in tech_files and included by %s, "
                  "but the PDK does not ship it." % (name, ", ".join(users)),
                  file=sys.stderr)
            return None, dropped
        # Comment the entry out in place, keeping its indentation.
        body = body[:match.end(1)] + "# " + body[match.end(1):]
        dropped.append(name)
    return body, list(reversed(dropped))


def missing_corners(body: str, models_dir: str) -> list:
    """Corner files the PDK ships but the list lacks."""
    listed = {match.group(2) for match in ENTRY.finditer(body)}
    return [entry for entry in sorted(os.listdir(models_dir))
            if re.match(r'corner\w*\.lib$', entry) and entry not in listed]


def missing_includes(body: str, models_dir: str) -> list:
    """Model files the verbatim-converted entries include but the list lacks."""
    listed = {match.group(2) for match in ENTRY.finditer(body)}
    missing = []
    for corner in VERBATIM.findall(body):
        for name in INCLUDE.findall(read(os.path.join(models_dir, corner))):
            if name in listed or name in missing:
                continue
            if os.path.isfile(os.path.join(models_dir, name)):
                missing.append(name)
            else:
                print("[WARN] %s includes %s, which the PDK does not ship."
                      % (corner, name), file=sys.stderr)
    return missing


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: %s <sg13g2tovc.py> <pdk_dir>" % sys.argv[0], file=sys.stderr)
        return 2
    converter, pdk_dir = sys.argv[1], sys.argv[2]
    models_dir = os.path.join(pdk_dir, "libs.tech", "ngspice", "models")

    content = read(converter)
    span = tech_files_span(content)
    if span is None:
        print("[ERROR] tech_files not found in %s." % converter, file=sys.stderr)
        print("[ERROR] The VACASK converter was restructured; "
              "fix_sg13g2_vacask_converter.py needs updating.", file=sys.stderr)
        return 1

    body, dropped = drop_stale(content[span[0]:span[1]], models_dir)
    if body is None:
        return 1
    corners = missing_corners(body, models_dir)
    corner_entries = "".join('    ( "%s", 0, 0 ), \n' % name for name in corners)
    # The new corners' includes count as well, so look at the list with them.
    added = missing_includes(body + corner_entries, models_dir)
    if corners or added:
        body += ("    # Added by fix_sg13g2_vacask_converter.py\n" + corner_entries
                 + "".join('    ( "%s", 1, None ), \n' % name for name in added))

    if not dropped and not corners and not added:
        print("[INFO] The VACASK converter's model file list matches the PDK, "
              "nothing to change.")
        return 0

    with open(converter, 'w') as f:
        f.write(content[:span[0]] + body + content[span[1]:])
    for name in dropped:
        print("[INFO] Dropped %s from the VACASK converter (no longer in the PDK)."
              % name)
    for name in corners:
        print("[INFO] Added %s to the VACASK converter (corner file of the PDK)."
              % name)
    for name in added:
        print("[INFO] Added %s to the VACASK converter (included by a corner file)."
              % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
