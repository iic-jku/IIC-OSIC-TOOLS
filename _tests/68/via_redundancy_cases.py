#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Writes small SG13G2 layouts with a known number of net-opening cuts, runs sak-via-redundancy.py on each and
# compares. Used by test_via_redundancy_sg13g2.sh. Usage: python3 via_redundancy_cases.py <work_dir>
# Exit code 0 when every case matches, 1 otherwise.

import json
import os
import subprocess
import sys

try:
    import pya
except ImportError:
    import klayout.db as pya

ACTIV, CONT, M1, VIA1, M2 = (1, 0), (6, 0), (8, 0), (19, 0), (10, 0)
M1_TEXT, M2_PIN, M2_TEXT = (8, 25), (10, 2), (10, 25)


def box(cell, layout, layer, x1, y1, x2, y2):
    cell.shapes(layout.layer(*layer)).insert(pya.DBox(x1, y1, x2, y2))


def label(cell, layout, layer, text, x, y):
    cell.shapes(layout.layer(*layer)).insert(pya.DText(text, x, y))


def via(cell, layout, x, y, layer=VIA1, size=0.19):
    box(cell, layout, layer, x - size / 2, y - size / 2, x + size / 2, y + size / 2)


def case(out_dir, name, build):
    layout = pya.Layout()
    layout.dbu = 0.001
    cell = layout.create_cell(name)
    build(cell, layout)
    path = os.path.join(out_dir, f"{name}.gds")
    layout.write(path)
    return path


def single_no_room(c, ly):
    # Metal1 and Metal2 lines that overlap in a 0.5 um square with one Via1: no room for two cuts (0.70 needed)
    box(c, ly, M1, 0, 0, 10, 0.5)
    box(c, ly, M2, 9.5, 0, 10, 10)
    via(c, ly, 9.75, 0.25)
    label(c, ly, M1_TEXT, "A", 0.25, 0.25)
    label(c, ly, M2_TEXT, "A", 9.75, 9.75)


def single_room(c, ly):
    # the same with a 1.0 x 0.5 um overlap: two cuts fit along x
    box(c, ly, M1, 0, 0, 10, 0.5)
    box(c, ly, M2, 9.0, 0, 10, 10)
    via(c, ly, 9.5, 0.25)
    label(c, ly, M1_TEXT, "A", 0.25, 0.25)
    label(c, ly, M2_TEXT, "A", 9.5, 9.75)


def double_cut(c, ly):
    single_room(c, ly)
    via(c, ly, 9.25, 0.25)
    via(c, ly, 9.75, 0.25)


def stub(c, ly):
    # one Via1 to a Metal2 stub that holds no terminal
    box(c, ly, M1, 0, 0, 10, 0.5)
    box(c, ly, M2, 9.0, 0, 10, 3)
    via(c, ly, 9.5, 0.25)
    label(c, ly, M1_TEXT, "A", 0.25, 0.25)


def loop(c, ly):
    # two single cuts between the same two polygons at different places: neither opens the net
    box(c, ly, M1, 0, 0, 10, 0.5)
    box(c, ly, M2, 0, 0, 0.5, 5)
    box(c, ly, M2, 0, 4.5, 10, 5)
    box(c, ly, M2, 9.5, 0, 10, 5)
    via(c, ly, 0.25, 0.25)
    via(c, ly, 9.75, 0.25)
    label(c, ly, M1_TEXT, "A", 5, 0.25)
    label(c, ly, M2_TEXT, "A", 5, 4.75)


def contacts(c, ly):
    # diffusion with a column of three contacts (parallel, fine) and diffusion with one contact (opens the net)
    box(c, ly, ACTIV, 0, 0, 0.5, 2)
    box(c, ly, ACTIV, 3, 0, 3.5, 0.5)
    for y in (0.3, 0.8, 1.3):
        via(c, ly, 0.25, y, CONT, 0.16)
    via(c, ly, 3.25, 0.25, CONT, 0.16)
    box(c, ly, M1, 0.05, 0.1, 3.45, 0.4)
    box(c, ly, M1, 0.05, 0.1, 0.45, 1.5)
    label(c, ly, M1_TEXT, "B", 1.5, 0.25)


def dangling(c, ly):
    # a Via1 with no Metal2 above it
    box(c, ly, M1, 0, 0, 10, 0.5)
    via(c, ly, 5, 0.25)
    label(c, ly, M1_TEXT, "A", 0.25, 0.25)


def black_box(c, ly):
    # a black box with two pin stripes of one name, the parent reaches each with one via: the stripes are joined
    # inside the black box, so neither via opens the net
    mac = ly.create_cell("bb")
    for x in (0, 8):
        box(mac, ly, M2, x, 0, x + 2, 10)
        box(mac, ly, M2_PIN, x, 0, x + 2, 10)
        label(mac, ly, M2_TEXT, "VDD", x + 1, 5)
    c.insert(pya.DCellInstArray(mac.cell_index(), pya.DTrans(pya.DVector(20, 0))))
    box(c, ly, M1, 0, 0, 31, 0.5)
    via(c, ly, 21, 0.25)
    via(c, ly, 29, 0.25)
    label(c, ly, M1_TEXT, "A", 0.25, 0.25)


CASES = [  # name, builder, opening cuts, with room, dangling cuts, extra arguments
    ("single_no_room", single_no_room, 1, 0, 0, []),
    ("single_room", single_room, 1, 1, 0, []),
    ("double_cut", double_cut, 0, 0, 0, []),
    ("stub", stub, 0, 0, 0, []),
    ("loop", loop, 0, 0, 0, []),
    ("contacts", contacts, 1, 0, 0, []),
    ("dangling", dangling, 0, 0, 1, []),
    ("black_box", black_box, 0, 0, 0, ["-b", "bb"]),
]

def run(args):
    proc = subprocess.run(["sak-via-redundancy.py", *args], capture_output=True, text=True, check=False)
    return proc.returncode, proc.stdout, proc.stderr


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    errors = 0
    for name, build, opening, room, dangle, extra in CASES:
        path = case(out, name, build)
        code, stdout, stderr = run(["--json", "-t", "ihp-sg13g2", "-w", out, *extra, path])
        try:
            body = json.loads(stdout)
            got = (body["opening_cuts"], body["with_room"], sum(body["dangling_cuts"].values()))
        except (ValueError, KeyError):
            print(f"[ERROR] case {name}: exit {code}, no result: {stderr.strip()}")
            errors += 1
            continue
        if code != 0 or got != (opening, room, dangle):
            print(f"[ERROR] case {name}: exit {code}, got {got}, want {(opening, room, dangle)}")
            errors += 1
        elif not os.path.isfile(os.path.join(out, f"{name}_via_redundancy.lyrdb")):
            print(f"[ERROR] case {name}: no marker database")
            errors += 1
    # --strict fails on a cut with room, and only then
    code, _o, _e = run(["--strict", "-t", "ihp-sg13g2", "-w", out, os.path.join(out, "single_room.gds")])
    if code != 1:
        print(f"[ERROR] --strict on single_room: exit {code}, want 1")
        errors += 1
    code, _o, _e = run(["--strict", "-t", "ihp-sg13g2", "-w", out, os.path.join(out, "single_no_room.gds")])
    if code != 0:
        print(f"[ERROR] --strict on single_no_room: exit {code}, want 0")
        errors += 1
    # -n keeps only the nets with a matching label
    code, stdout, _e = run(["--json", "-n", "nomatch", "-t", "ihp-sg13g2", "-w", out,
                            os.path.join(out, "single_room.gds")])
    body = json.loads(stdout) if stdout else {}
    if code != 0 or body.get("nets_checked") != 0 or body.get("opening_cuts") != 0:
        print(f"[ERROR] -n nomatch: exit {code}, {body.get('nets_checked')} nets, {body.get('opening_cuts')} cuts")
        errors += 1
    # a PDK without a metal stack is a usage error
    code, _o, _e = run(["-t", "asap7", "-w", out, os.path.join(out, "loop.gds")])
    if code != 3:
        print(f"[ERROR] PDK without a metal stack: exit {code}, want 3")
        errors += 1
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
