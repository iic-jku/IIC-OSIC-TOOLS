#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Adapt the ASAP7_for_KLayout DRC deck to batch use and add the passive rules.

The deck (drc_ASAP7.lydrc) takes its report path from $output and runs on a
fixed 4 threads. LibreLane's generic KLayout.DRC step and sak-drc.sh pass
-rd report=<file> and -rd threads=<n>, so:

* $report is accepted as the report path, $output stays as an alias.
* $threads sets the thread count, 4 stays the default.
* A relative report path is anchored to the working directory. KLayout
  resolves it against the layout file otherwise, so the report lands next to
  the GDS.
* V5.M6.AUX.2 compares the V5 width with the vertical edges of M6. M6 runs
  horizontally, like M4, whose rule V3.M4.AUX.2 takes the horizontal edges.
  With the vertical edges every V5 on a minimum-width M6 wire is flagged.
* GATE.W.1 allows the gate lengths of asap7_passives.MOS_LENGTHS and
  IO_LENGTHS, not 20 nm only. The longer gates are an IIC-OSIC-TOOLS addition for analog design.
  GATE.S.1 is left as it is: the deck checks it as a gate spacing of exactly
  34 nm, which holds for every length.
* V0 may land on the thin-film resistor layer TFR (121/0) instead of LISD or
  LIG. TFR and the other passive devices are an IIC-OSIC-TOOLS addition, their
  rules (asap7_passives.drc) are inserted before the run time is printed and
  the rule file is removed.

Each replacement has to hit exactly once, so an upstream change of these
lines fails the build instead of shipping a deck that ignores the options.

Usage: fix_asap7_drc_deck.py <asap7.lydrc> <asap7_passives.drc>
"""

import sys
from pathlib import Path
from xml.sax.saxutils import escape

import asap7_passives

GATE_LENGTHS = asap7_passives.MOS_LENGTHS + asap7_passives.IO_LENGTHS

REPLACEMENTS = [
    (
        'if $output\n  report("ASAP7 DRC runset", $output)\nelse\n  report("ASAP7 DRC runset", "ASAP7_DRC.lyrdb")\nend',
        'report_file = $report || $output || "ASAP7_DRC.lyrdb"\n'
        'report("ASAP7 DRC runset", File.expand_path(report_file, Dir.pwd))',
    ),
    ("threads(4)", "threads(($threads || 4).to_i)"),
    (
        "v5.not_interacting(m6.enclosing(v5, 1.dbu, projection, two_opposite_sides_allowed).edges.with_angle(90))",
        "v5.not_interacting(m6.enclosing(v5, 1.dbu, projection, two_opposite_sides_allowed).edges.with_angle(0))",
    ),
    ("(v0 - lig.sized(1.nm) - lisd)", "(v0 - lig.sized(1.nm) - lisd - input(121, 0))"),
    (
        'gate.drc(width(projection) != 20.nm).with_angle(90).output("GATE.W.1", '
        '"GATE.W.1 : Exact horizontal width of GATE : 20nm")',
        "gate" + "".join(f".without_bbox_width({n}.nm)" for n in GATE_LENGTHS)
        + '.output("GATE.W.1", "GATE.W.1 : Horizontal width of GATE must be one of : '
        + ", ".join(str(n) for n in GATE_LENGTHS) + ' nm")',
    ),
]
PASSIVES_BEFORE = "# time spent for the DRC\n"


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    path = Path(sys.argv[1])
    rules = Path(sys.argv[2])
    text = path.read_text()
    # the deck is the text of an XML macro
    REPLACEMENTS.append((PASSIVES_BEFORE, escape(rules.read_text()) + "\n" + PASSIVES_BEFORE))
    for old, new in REPLACEMENTS:
        count = text.count(old)
        if count != 1:
            sys.exit(f"[ERROR] {path}: expected one occurrence of {old.splitlines()[0]!r}, found {count}")
        text = text.replace(old, new)
    path.write_text(text)
    rules.unlink()
    print(f"[INFO] Adapted {path} to -rd report= and -rd threads= and added the passive rules.")


if __name__ == "__main__":
    main()
