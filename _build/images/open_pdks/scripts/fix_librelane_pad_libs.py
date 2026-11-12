#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Register the IO-cell Liberty files for every core-voltage corner in LibreLane.

The LibreLane IO configuration of the IHP PDKs
(``libs.tech/librelane/<pdk>_io/config.tcl``) fills ``PAD_LIBS`` for the
1.2 V core corners only (``*_typ_1p20V_25C``, ``*_fast_1p32V_m40C``,
``*_slow_1p08V_125C``). The standard-cell library and the IO library both ship
the 1.5 V corners as well (``typ_1p50V_25C``, ``fast_1p65V_m40C``,
``slow_1p35V_125C``), and designs that list those in ``STA_CORNERS`` get no IO
Liberty there. Since OpenROAD 26Q4 (the revision of LibreLane 3.1.0.dev6) this
is an error as soon as the netlist contains a pad cell:

    [STA-1112] Liberty cell sg13g2_io_fast_1p32V_3p6V_m40C/sg13g2_Filler10000
    for corner nom_typ_1p50V_25C/min not found.

This script adds a ``PAD_LIBS`` entry for every IO Liberty file in
``libs.ref/<pdk>_io/lib`` whose corner is not registered yet. The corner key is
derived from the file name, so ``sg13g2_io_typ_1p5V_3p3V_25C.lib`` becomes
``*_typ_1p50V_25C``, the key the standard-cell Liberty of the same corner uses.
Existing entries are left alone, which makes a repeated run a no-op.

Run it before gzip_liberty.sh, which then rewrites the added ``.lib`` paths to
``.lib.gz`` together with the upstream ones.

Usage: fix_librelane_pad_libs.py <pdk-directory> <io-library-name>
"""

import re
import sys
from pathlib import Path

# <io-lib>_<process>_<core voltage>V_<io voltage>V_<temperature>.lib
IO_LIB_RE = re.compile(
    r"_(?P<proc>typ|fast|slow)_(?P<core>\d+p\d+)V_\d+p\d+V_(?P<temp>m?\d+C)\.lib$"
)
PAD_LIBS_KEY_RE = re.compile(r'dict set ::env\(PAD_LIBS\) "([^"]+)"')


def corner_key(proc: str, core: str, temp: str) -> str:
    """Return the LibreLane corner pattern, with the voltage in 2 decimals."""
    whole, frac = core.split("p")
    return f"*_{proc}_{whole}p{frac.ljust(2, '0')}V_{temp}"


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: fix_librelane_pad_libs.py <pdk-directory> <io-library-name>")
        return 1
    pdk_dir = Path(sys.argv[1])
    io_lib = sys.argv[2]
    config = pdk_dir / "libs.tech" / "librelane" / io_lib / "config.tcl"
    lib_dir = pdk_dir / "libs.ref" / io_lib / "lib"

    if not config.is_file() or not lib_dir.is_dir():
        print(f"[ERROR] {config} or {lib_dir} not found.")
        return 1

    text = config.read_text()
    entries = list(PAD_LIBS_KEY_RE.finditer(text))
    if not entries:
        print(f"[ERROR] No PAD_LIBS entries found in {config}, layout changed upstream?")
        return 1
    known = {m.group(1) for m in entries}

    added = []
    for lib in sorted(lib_dir.glob(f"{io_lib}_*.lib")):
        m = IO_LIB_RE.search(lib.name)
        if not m:
            continue
        key = corner_key(m["proc"], m["core"], m["temp"])
        if key in known:
            continue
        added.append(
            f'dict set ::env(PAD_LIBS) "{key}" "\\\n'
            f"    $::env(PDK_ROOT)/$::env(PDK)/libs.ref/{io_lib}/lib/{lib.name}\\\n"
            '"\n'
        )
        known.add(key)

    if not added:
        print(f"[INFO] PAD_LIBS in {config} already covers every IO corner.")
        return 0

    # Insert after the closing quote of the last upstream PAD_LIBS entry.
    first_line_end = text.index("\n", entries[-1].end())
    end = text.index('"\n', first_line_end + 1) + 2
    config.write_text(text[:end] + "".join(added) + text[end:])
    print(f"[INFO] Added {len(added)} PAD_LIBS corner(s) to {config}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
