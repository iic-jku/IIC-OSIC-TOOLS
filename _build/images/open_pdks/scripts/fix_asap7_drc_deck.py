#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Adapt the ASAP7_for_KLayout DRC deck to batch use.

The deck (drc_ASAP7.lydrc) takes its report path from $output and runs on a
fixed 4 threads. LibreLane's generic KLayout.DRC step and sak-drc.sh pass
-rd report=<file> and -rd threads=<n>, so:

* $report is accepted as the report path, $output stays as an alias.
* $threads sets the thread count, 4 stays the default.
* A relative report path is anchored to the working directory. KLayout
  resolves it against the layout file otherwise, so the report lands next to
  the GDS.

Each replacement has to hit exactly once, so an upstream change of these
lines fails the build instead of shipping a deck that ignores the options.

Usage: fix_asap7_drc_deck.py <asap7.lydrc>
"""

import sys
from pathlib import Path

REPLACEMENTS = [
    (
        'if $output\n  report("ASAP7 DRC runset", $output)\nelse\n  report("ASAP7 DRC runset", "ASAP7_DRC.lyrdb")\nend',
        'report_file = $report || $output || "ASAP7_DRC.lyrdb"\n'
        'report("ASAP7 DRC runset", File.expand_path(report_file, Dir.pwd))',
    ),
    ("threads(4)", "threads(($threads || 4).to_i)"),
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = Path(sys.argv[1])
    text = path.read_text()
    for old, new in REPLACEMENTS:
        count = text.count(old)
        if count != 1:
            sys.exit(f"[ERROR] {path}: expected one occurrence of {old.splitlines()[0]!r}, found {count}")
        text = text.replace(old, new)
    path.write_text(text)
    print(f"[INFO] Adapted {path} to -rd report= and -rd threads=.")


if __name__ == "__main__":
    main()
