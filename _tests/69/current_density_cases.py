#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Writes small SG13G2 layouts with currents whose density, resistance and stage are known by hand, runs
# sak-current-density.py on each and compares. Used by test_current_density_sg13g2.sh.
# Usage: python3 current_density_cases.py <work_dir>. Exit code 0 when every case matches, 1 otherwise.

import json
import os
import subprocess
import sys
import time

try:
    import pya
except ImportError:
    import klayout.db as pya

ACTIV, CONT, M1, VIA1, M2, TM2, PASSIV = (1, 0), (6, 0), (8, 0), (19, 0), (10, 0), (134, 0), (9, 0)
M1_PIN, M1_TEXT, M2_PIN, M2_TEXT, TM2_TEXT = (8, 2), (8, 25), (10, 2), (10, 25), (134, 25)
RS_M1 = 0.135  # Ohm/sq of Metal1 in the stack (sg13g2_tech.lef)


def box(cell, layout, layer, x1, y1, x2, y2):
    cell.shapes(layout.layer(*layer)).insert(pya.DBox(x1, y1, x2, y2))


def label(cell, layout, layer, text, x, y):
    cell.shapes(layout.layer(*layer)).insert(pya.DText(text, x, y))


def via(cell, layout, x, y, size=0.19):
    box(cell, layout, VIA1, x - size / 2, y - size / 2, x + size / 2, y + size / 2)


def write_gds(path, name, build):
    layout = pya.Layout()
    layout.dbu = 0.001
    cell = layout.create_cell(name)
    build(layout, cell)
    layout.write(path)


def write_text(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def strip(width, y0=0.0):
    """A 20 um Metal1 line with the source label S at one end and the load label L at the other."""
    def build(ly, c):
        box(c, ly, M1, 0, y0, 20, y0 + width)
        label(c, ly, M1_TEXT, "S", 0.25, y0 + width / 2)
        label(c, ly, M1_TEXT, "L", 19.75, y0 + width / 2)
    return build


def vias(count):
    """2 um lines of Metal1 (source S) and Metal2 (load L) that overlap on 1 um, joined by 2 or 4 Via1."""
    def build(ly, c):
        box(c, ly, M1, 0, 0, 10, 2)
        box(c, ly, M2, 9, 0, 20, 2)
        label(c, ly, M1_TEXT, "S", 0.5, 1)
        label(c, ly, M2_TEXT, "L", 19.5, 1)
        spots = [(9.5, 0.6), (9.5, 1.4)] if count == 2 else [(9.25, 0.6), (9.25, 1.4), (9.75, 0.6), (9.75, 1.4)]
        for x, y in spots:
            via(c, ly, x, y)
    return build


def macro_cell(ly):
    mac = ly.create_cell("mac")
    box(mac, ly, M2, 0, 0, 10, 10)
    box(mac, ly, M2_PIN, 0, 0, 10, 10)
    label(mac, ly, M2_TEXT, "VDD", 5, 5)
    box(mac, ly, M1, 1, 1, 2, 9)  # inside the black box, must not count
    return mac


def write_macro(path, extra=False):
    layout = pya.Layout()
    layout.dbu = 0.001
    mac = macro_cell(layout)
    if extra:
        box(mac, layout, M1, 3, 1, 4, 9)
    layout.write(path)


def chip(ly, c):
    mac = macro_cell(ly)
    c.insert(pya.DCellInstArray(mac.cell_index(), pya.DTrans(pya.DVector(20, 0))))
    box(c, ly, M2, 0, 4.6, 21, 5.4)  # 0.8 um of Metal2 into the macro pin: limit 1.6 mA
    label(c, ly, M2_TEXT, "VDD", 0.25, 5)


def view_macro(ly, c):
    box(c, ly, M1, 0, 0, 20, 0.3)  # pin VDD on a 0.3 um line: 1 mA cannot pass the screen
    label(c, ly, M1_TEXT, "VDD", 0.2, 0.15)
    box(c, ly, M1, 0, 2, 20, 2.3)
    label(c, ly, M1_TEXT, "VSS", 0.2, 2.15)
    # OUT carries no pin current but reaches a diffusion, so it may carry the whole 1 mA of the macro
    box(c, ly, M1, 0, 4, 20, 4.3)
    label(c, ly, M1_TEXT, "OUT", 0.2, 4.15)
    box(c, ly, ACTIV, 19, 3.9, 20, 4.4)
    for x in (19.3, 19.7):
        box(c, ly, CONT, x - 0.08, 4.07, x + 0.08, 4.23)


def hairpin(ly, c):
    """A 0.2 um Metal2 hairpin with 0.21 um between its arms, both labels at the open end: the current goes round."""
    box(c, ly, M2, 0, 0, 20, 0.2)
    box(c, ly, M2, 0, 0.41, 20, 0.61)
    box(c, ly, M2, 19.8, 0, 20, 0.61)
    label(c, ly, M2_TEXT, "S", 0.1, 0.1)
    label(c, ly, M2_TEXT, "L", 0.1, 0.51)


def diagonal(ly, c):
    """A 45 degree Metal2 line 1 um wide (1.414 um across on the pixel grid) between two wide pads."""
    w = 2 ** 0.5
    c.shapes(ly.layer(*M2)).insert(pya.DPolygon([pya.DPoint(0, 0), pya.DPoint(w, 0), pya.DPoint(15 + w, 15),
                                                 pya.DPoint(15, 15)]))
    box(c, ly, M2, -3, -3, 3, 0)
    box(c, ly, M2, 13.5, 15, 18, 18)
    label(c, ly, M2_TEXT, "S", 0, -1.5)
    label(c, ly, M2_TEXT, "L", 15.7, 16.5)


def pad(ly, c):
    """A TopMetal2 pad under a passivation opening feeds a 2 um TopMetal2 line (32 mA) to the load label."""
    box(c, ly, TM2, 0, 0, 10, 10)
    box(c, ly, PASSIV, 1, 1, 9, 9)
    label(c, ly, TM2_TEXT, "P", 5, 5)
    box(c, ly, TM2, 10, 4, 40, 6)
    label(c, ly, TM2_TEXT, "L", 39, 5)


def rail(ly, c):
    """Five black-box cells whose Metal1 pin shapes form a 0.44 um rail, fed from the source label at one end."""
    cell = ly.create_cell("sc")
    box(cell, ly, M1, 0, 0, 2, 0.44)
    box(cell, ly, M1_PIN, 0, 0, 2, 0.44)
    label(cell, ly, M1_TEXT, "VDD", 1, 0.22)
    for k in range(5):
        c.insert(pya.DCellInstArray(cell.cell_index(), pya.DTrans(pya.DVector(2 + 2 * k, 0))))
    box(c, ly, M1, 0, 0, 2, 0.44)
    label(c, ly, M1_TEXT, "S", 0.5, 0.22)


def two_stripes(ly, c):
    """A macro with two Metal2 pin stripes joined inside by Metal1, only one labelled, the chip feeds the other."""
    mac = ly.create_cell("mm")
    for x, name in ((0, ""), (8, "VDD")):
        box(mac, ly, M2, x, 0, x + 2, 10)
        box(mac, ly, M2_PIN, x, 0, x + 2, 10)
        if name:
            label(mac, ly, M2_TEXT, name, x + 1, 5)
    box(mac, ly, M1, 0, 0, 10, 2)
    for x in (0.5, 1.5, 8.5, 9.5):
        via(mac, ly, x, 1)
    c.insert(pya.DCellInstArray(mac.cell_index(), pya.DTrans(pya.DVector(20, 0))))
    box(c, ly, M2, 0, 4, 21, 5)  # 1 um of Metal2 onto the unlabelled stripe at x 20 to 22 only
    label(c, ly, M2_TEXT, "S", 0.5, 4.5)


def run(args):
    proc = subprocess.run(["sak-current-density.py", *args], capture_output=True, text=True, check=False)
    try:
        body = json.loads(proc.stdout)
    except ValueError:
        body = {}
    return proc.returncode, body, proc.stderr


def net_of(body, name):
    for net in body.get("nets", []):
        if name in net["net"].split(","):
            return net
    return None


class Checker:
    def __init__(self):
        self.errors = 0

    def expect(self, ok, text):
        if not ok:
            print(f"[ERROR] {text}")
            self.errors += 1


ONE_LOAD = "nets:\n  S:\n    sources: [S]\n    loads:\n      - {label: L, current_ma: %s, source: test}\n"


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    chk = Checker()
    common = ["--json", "--max", "0", "-t", "ihp-sg13g2", "-w", out]

    def check_case(name, build, budget, expect_code, verdict=None, stage=None, ratio=None, tol=0.02, ir=None,
                   pixel="0.5", net="S"):
        gds = os.path.join(out, f"{name}.gds")
        yml = os.path.join(out, f"{name}.yaml")
        write_gds(gds, name, build)
        write_text(yml, budget)
        code, body, err = run(["check", *common, "--pixel", pixel, "-b", yml, gds])
        chk.expect(code == expect_code, f"{name}: exit {code}, want {expect_code} {err.strip()}")
        if verdict is None:
            return body
        entry = net_of(body, net)
        if entry is None:
            chk.expect(False, f"{name}: no result for net {net}")
            return body
        chk.expect(entry["verdict"] == verdict, f"{name}: verdict {entry['verdict']}, want {verdict}")
        if stage:
            chk.expect(entry["stage"].startswith(stage), f"{name}: stage {entry['stage']}, want {stage}")
        if ratio is not None:
            got = entry["worst_ratio"]
            chk.expect(got is not None and abs(got - ratio) <= tol * ratio,
                       f"{name}: worst ratio {got}, want {ratio:.4f} +- {tol * 100:.0f} %")
        if ir is not None:
            with open(body["report"], encoding="utf-8") as fh:
                lines = [ln for ln in fh.read().splitlines() if "label L:" in ln]
            got = float(lines[0].split(":")[-1]) if lines else None
            chk.expect(got is not None and abs(got - ir) <= 0.03 * ir, f"{name}: IR drop {got} mV, want {ir:.3f}")
        return body

    # 0.5 um of Metal1 carries 0.5 mA, so 1 mA is twice the limit, and the 19.5 um between the labels are
    # 0.135 * 19.5 / 0.5 = 5.265 Ohm
    check_case("strip_fail", strip(0.5), ONE_LOAD % "1.0", 1, "fail", "solve", 2.0, ir=1.0 * RS_M1 * 19.5 / 0.5)
    # 0.3 um off the pixel grid: the flat band gives 0.36 mA, so 0.5 mA is 1.389 of it
    check_case("strip_offgrid", strip(0.3, 0.1), ONE_LOAD % "0.5", 1, "fail", "solve", 0.5 / 0.36, pixel="0.25",
               ir=0.5 * RS_M1 * 19.5 / 0.3)
    # below the floor of one Cont (0.3 mA) no geometry is looked at
    check_case("floor", strip(0.5), ONE_LOAD % "0.2", 0, "pass", "floor")
    # 5 um of Metal1 hold 2 mA everywhere, the screen proves it
    check_case("screen", strip(5.0), ONE_LOAD % "2.0", 0, "pass", "screen")
    # two Via1 share 1 mA: 0.5 mA each against 0.4 mA
    check_case("vias_fail", vias(2), ONE_LOAD % "1.0", 1, "fail", "solve", 1.25, tol=0.03)
    # four Via1: about 0.25 mA each, a warning but a pass
    body = check_case("vias_pass", vias(4), ONE_LOAD % "1.0", 0, "pass", "solve")
    entry = net_of(body, "S")
    chk.expect(entry is not None and entry["worst_ratio"] is not None and 0.55 < entry["worst_ratio"] < 0.8,
               f"vias_pass: worst ratio {entry and entry['worst_ratio']}, want 0.55 to 0.8")
    # a load label that is not on the net is an input error, and so is a key the budget does not know
    check_case("bad_label", strip(0.5), "nets:\n  S:\n    sources: [S]\n    loads:\n"
               "      - {label: X, current_ma: 1, source: test}\n", 2)
    body = check_case("bad_key", strip(0.5), "black_boxes: [x]\n" + ONE_LOAD % "1.0", 2)
    chk.expect("unknown key" in body.get("error", ""), f"bad_key: {body.get('error')}")
    # the arms of the hairpin share pixels but not metal: 1 mA goes round through 0.2 um (0.6 mA)
    check_case("hairpin", hairpin, ONE_LOAD % "1.0", 1, "fail", "solve", 1.0 / 0.6, tol=0.03)
    # the 45 degree line is 1 um wide (2 mA), not the 1.414 um a pixel line crosses: 2.5 mA is 1.25 of it
    check_case("diagonal", diagonal, ONE_LOAD % "2.5", 1, "fail", "solve", 1.25, tol=0.06)
    # a pad as the source: 40 mA through 2 um of TopMetal2 (32 mA)
    check_case("pad", pad, "nets:\n  P:\n    loads:\n      - {label: L, current_ma: 40, source: test}\n", 1, "fail",
               "solve", 40 / 32, tol=0.03, net="P")
    # 2 mA spread over five cells of a 0.44 um rail (0.44 mA): close to 2 mA flows past the source
    body = check_case("rail", rail, "black_box: [sc]\nnets:\n  S:\n    sources: [S]\n    loads:\n"
                      "      - {cells: [sc], pin: VDD, current_ma: 2, source: test}\n", 1, "fail", "solve")
    entry = net_of(body, "S")
    chk.expect(entry is not None and entry["worst_ratio"] is not None and 3.5 < entry["worst_ratio"] < 4.6,
               f"rail: worst ratio {entry and entry['worst_ratio']}, want 3.5 to 4.6")
    # the unlabelled stripe takes the name VDD from the stripe it joins inside the macro, so its 1 mA reaches S
    mm_gds = os.path.join(out, "mm.gds.gz")
    mm_view = os.path.join(out, "mm_current.yaml")
    layout = pya.Layout()
    layout.dbu = 0.001
    two_stripes(layout, layout.create_cell("unused"))
    layout.delete_cell(layout.cell("unused").cell_index())
    layout.write(mm_gds)
    code, body, err = run(["view", "--json", "-t", "ihp-sg13g2", "-o", mm_view, "--gds", mm_gds, "--state", "active",
                           "--source", "test", "--current", "VDD=1"])
    chk.expect(code == 0, f"view mm (gzipped GDS): exit {code} {err.strip()}")
    body = check_case("stripes", two_stripes, "views:\n  - {view: mm_current.yaml, state: active}\n"
                      "nets:\n  S:\n    sources: [S]\n", 0, "pass", "screen")
    entry = net_of(body, "S")
    chk.expect(entry is not None and abs(entry["current_ma"] - 1.0) < 1e-9,
               f"stripes: current of S {entry and entry['current_ma']}, want 1.0")

    # the view from a data file of '<pin> <ampere>' lines and from an OpenSTA power report
    data = os.path.join(out, "currents.txt")
    write_text(data, "# from ngspice\nVDD 0.0012\nVSS -0.0012\n")
    code, body, err = run(["view", "--json", "-t", "ihp-sg13g2", "-o", os.path.join(out, "vm_data.yaml"), "--gds",
                           os.path.join(out, "strip_fail.gds"), "--state", "active", "--source", "test", "--data",
                           data])
    chk.expect(code == 2 and "no pin label" in body.get("error", ""),
               f"--data with unknown pins: exit {code}, {body.get('error')}")
    rpt = os.path.join(out, "power.rpt")
    write_text(rpt, "Group  Internal  Switching  Leakage  Total\nTotal  1.0e-3  2.0e-3  3.0e-4  3.3e-3  100.0%\n")
    for kind, extra, want in (("--data", [data], 1.2), ("--sta-power", [rpt, "--supply", "VDD=1.5", "--ground", "VSS"],
                                                        2.2)):
        vm = os.path.join(out, "vm2.gds")
        write_gds(vm, "vm", view_macro)
        code, body, err = run(["view", "--json", "-t", "ihp-sg13g2", "-o", os.path.join(out, "vm2.yaml"), "--gds", vm,
                               "--state", "active", "--source", "test", kind, *extra])
        got = body.get("pins_ma", {}).get("VDD")
        chk.expect(code == 0 and got is not None and abs(got - want) < 1e-9, f"view {kind}: VDD {got}, want {want}")

    # a black-box macro with a current view: 2 mA through 0.8 um of Metal2 (1.6 mA)
    mac_gds = os.path.join(out, "mac.gds")
    mac_view = os.path.join(out, "mac_current.yaml")
    write_macro(mac_gds)
    code, body, err = run(["view", "--json", "-t", "ihp-sg13g2", "-o", mac_view, "--gds", mac_gds, "--state", "active",
                           "--source", "test", "--current", "VDD=2"])
    chk.expect(code == 0, f"view: exit {code} {err.strip()}")
    budget = "views:\n  - {view: mac_current.yaml, state: active}\nnets:\n  VDD:\n    sources: [VDD]\n"
    check_case("macro", chip, budget, 1, "fail", "solve", 2.0 / 1.6, net="VDD")
    # writing the same macro again a second later changes only the GDS time stamps, the view stays valid
    time.sleep(1.1)
    write_macro(mac_gds)
    code, body, err = run(["check", *common, "-b", os.path.join(out, "macro.yaml"), os.path.join(out, "macro.gds")])
    chk.expect(code == 1, f"view after a rewrite with the same content: exit {code}, want 1 {body.get('error')}")
    # one more shape in the macro makes the view stale
    write_macro(mac_gds, extra=True)
    code, body, err = run(["check", *common, "-b", os.path.join(out, "macro.yaml"), os.path.join(out, "macro.gds")])
    chk.expect(code == 2 and "stale" in body.get("error", ""), f"stale view: exit {code}, {body.get('error')}")

    # a macro checked on its own: VDD (1 mA on 0.3 um) stays unresolved, VSS (0.1 mA) passes at the floor, and OUT,
    # which carries no pin current but reaches a diffusion, is bounded by the macro's whole 1 mA and stays unresolved
    vm_gds = os.path.join(out, "vm.gds")
    vm_view = os.path.join(out, "vm_current.yaml")
    write_gds(vm_gds, "vm", view_macro)
    code, body, err = run(["view", "--json", "-t", "ihp-sg13g2", "-o", vm_view, "--gds", vm_gds, "--state", "active",
                           "--source", "test", "--current", "VDD=1", "--current", "VSS=-0.1"])
    chk.expect(code == 0 and body.get("warnings"), f"view vm: exit {code}, want a warning on the unbalanced pins")
    code, body, err = run(["check", *common, "-v", vm_view, "-s", "active", vm_gds])
    chk.expect(code == 0, f"view mode: exit {code}, want 0 {err.strip()}")
    for name, verdict in (("VDD", "unresolved"), ("VSS", "pass"), ("OUT", "unresolved")):
        entry = net_of(body, name)
        chk.expect(entry is not None and entry["verdict"] == verdict,
                   f"view mode {name}: {entry and entry['verdict']}, want {verdict}")
    # the view must belong to the layout checked with it
    code, body, err = run(["check", *common, "-v", vm_view, "-s", "active", os.path.join(out, "strip_fail.gds")])
    chk.expect(code == 2, f"view of another layout: exit {code}, want 2")
    # a PDK without a metal stack is a usage error
    code, body, err = run(["check", "--json", "-t", "asap7", "-w", out, "-v", vm_view, "-s", "active", vm_gds])
    chk.expect(code == 3, f"PDK without a metal stack: exit {code}, want 3")
    return 1 if chk.errors else 0


if __name__ == "__main__":
    sys.exit(main())
