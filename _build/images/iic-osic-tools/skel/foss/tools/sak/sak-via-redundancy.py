#!/usr/bin/env python3
# ========================================================================
# Single cuts that open a net when they fail (via redundancy check)
#
# SPDX-FileCopyrightText: 2026 Harald Pretl and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sak-via-redundancy.py [--json] [--max <n>] [-t <pdk>] [-c <cell>] [-b <pattern>]... [-k <pattern>]...
#                              [-n <net>]... [-w <workdir>] [--strict] <layout>
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

"""Report the single cuts whose failure opens a net.

A lone via or contact is legal and connected, so DRC and LVS never flag it, but a
void or an electromigration failure there opens the net. This command finds the
cuts that are the only connection between two parts of a net that both hold a
terminal (a device, a pad, a label of the top cell or a black-box pin). Parallel
cuts (a contact column, a via array) and cuts to a stub without a terminal are
not reported. Each reported cut gets a room test: whether the overlap of its two
conductors holds a second cut by the size, space and enclosure rules of the PDK.

The conductors and cuts come from the metal stack of the PDK given with ``-t``
(default ``$PDK``, see ``sak_tech.STACKS``). ``-b`` leaves cells out as black
boxes (only their pin shapes stay), ``-k`` keeps cells a ``-b`` pattern matches,
``-n`` limits the report to nets whose label matches a pattern.

Outputs in the work directory (``-w``, default: current directory):
``<cell>_via_redundancy.rpt`` (text) and ``<cell>_via_redundancy.lyrdb``
(markers for the KLayout marker browser).

Exit codes: 0 success (the findings are a report, see ``--strict``), 1 cuts with
room for a second cut and ``--strict``, 2 layout missing or unreadable, 3 wrong
usage (including a PDK without a metal stack).
"""

import fnmatch
import os
import sys
import time
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # noqa: E402
import sak_tech  # noqa: E402

TOOL = "sak-via-redundancy"

try:
    import sak_netgraph  # noqa: E402
except ImportError:
    sak_json.fail(TOOL, "KLayout Python module not found (tried 'pya' and 'klayout.db')", "--json" in sys.argv[1:])


def net_selected(net, patterns: list) -> bool:
    """Whether a net matches one of the patterns by one of its labels (or its name)."""
    if not patterns:
        return True
    names = set(net.labels) or {net.name}
    return any(fnmatch.fnmatchcase(name, p) for name in names for p in patterns)


def analyse(ext, patterns: list) -> tuple[list, int]:
    """The net-opening cuts as dicts, and the number of nets looked at."""
    spec_of = ext.cut_specs
    cond_of = ext.conductors
    findings = []
    nets = 0
    for net in ext.nets:
        if not net.cuts or not net_selected(net, patterns):
            continue
        nets += 1
        for c in ext.opening_cuts(net):
            spec = spec_of[ext.cut_spec[c]]
            box = ext.cut_poly[c].bbox()
            findings.append({
                "cut": c,
                "layer": spec["name"],
                "net": net.name,
                "lower": cond_of[ext.node_cond[ext.cut_lower[c]]]["name"],
                "upper": cond_of[ext.node_cond[ext.cut_upper[c]]]["name"],
                "x_um": round(ext.cut_center[c][0] * ext.dbu, 4),
                "y_um": round(ext.cut_center[c][1] * ext.dbu, 4),
                "room": ext.has_room(c),
                "cell": ext.owner(c),
                "box": box,
            })
    findings.sort(key=lambda f: (f["room"] is not True, f["layer"], f["net"], f["x_um"], f["y_um"]))
    return findings, nets


def room_text(room) -> str:
    return {True: "room for a second cut", False: "no room", None: "room not tested"}[room]


def summary_body(findings: list, ext, nets: int) -> dict:
    by_layer = defaultdict(Counter)
    by_cell = defaultdict(Counter)
    by_net = Counter()
    for f in findings:
        key = {True: "room", False: "no_room", None: "untested"}[f["room"]]
        by_layer[f["layer"]][key] += 1
        by_cell[f["cell"]][key] += 1
        by_net[f["net"]] += 1
    dangling = ext.dangling_cuts()
    dangling_by_layer = Counter(ext.cut_specs[ext.cut_spec[c]]["name"] for c in dangling)
    return {
        "nets_checked": nets,
        "cuts": len(ext.cut_spec),
        "black_box_instances": len(ext.bb_instances),
        "opening_cuts": len(findings),
        "with_room": sum(1 for f in findings if f["room"] is True),
        "without_room": sum(1 for f in findings if f["room"] is False),
        "by_layer": {k: dict(v) for k, v in sorted(by_layer.items())},
        "by_cell": {k: dict(v) for k, v in sorted(by_cell.items(), key=lambda kv: -sum(kv[1].values()))},
        "by_net": dict(by_net.most_common()),
        "dangling_cuts": dict(sorted(dangling_by_layer.items())),
        "unattached_labels": sorted({lab[0] for lab in ext.unattached_labels()}),
    }


def report_lines(body: dict, findings: list, limit: int, header: list) -> list:
    lines = list(header)
    lines.append(f"Nets checked: {body['nets_checked']}, cuts: {body['cuts']}, "
                 f"black-box instances: {body['black_box_instances']}")
    lines.append(f"Net-opening single cuts: {body['opening_cuts']} ({body['with_room']} with room for a second "
                 f"cut, {body['without_room']} without)")
    if body["by_layer"]:
        lines.append("By cut layer (room / no room):")
        for layer, cnt in body["by_layer"].items():
            lines.append(f"  {layer}: {cnt.get('room', 0)} / {cnt.get('no_room', 0)}"
                         + (f", {cnt['untested']} not tested" if cnt.get("untested") else ""))
    if body["by_cell"]:
        lines.append("By cell that draws the cut (room / no room):")
        for cell, cnt in body["by_cell"].items():
            lines.append(f"  {cell}: {cnt.get('room', 0)} / {cnt.get('no_room', 0)}")
    if body["dangling_cuts"]:
        lines.append("Cuts that miss a conductor on one side (not checked): "
                     + ", ".join(f"{k} {v}" for k, v in body["dangling_cuts"].items()))
    if body["unattached_labels"]:
        lines.append("Labels on no conductor polygon: " + ", ".join(body["unattached_labels"]))
    shown = findings if limit == 0 else findings[:limit]
    if shown:
        lines.append(f"Cuts ({len(shown)} of {len(findings)}):")
        for f in shown:
            lines.append(f"  {f['layer']} at ({f['x_um']}, {f['y_um']}) on {f['net']}, {f['lower']} to "
                         f"{f['upper']}, {room_text(f['room'])}, drawn in {f['cell']}")
    return lines


def write_markers(path: str, ext, findings: list) -> None:
    markers = sak_netgraph.Markers(TOOL, ext.top.name, ext.dbu)
    for f in findings:
        category = f"{f['layer']} {room_text(f['room'])}"
        markers.add(category, f["box"], f"net {f['net']}, {f['lower']} to {f['upper']}, drawn in {f['cell']}")
    markers.save(path)


def main() -> None:
    parser = sak_json.SakArgumentParser(tool=TOOL, description="Report the single cuts whose failure opens a net.")
    parser.add_argument("layout", help="GDS2 or OASIS layout (optionally gzipped)")
    parser.add_argument("-t", "--tech", default=os.getenv("PDK"), metavar="PDK",
                        help="PDK of the metal stack (default: environment variable PDK)")
    parser.add_argument("-c", "--cell", metavar="CELL", help="cell to check (default: the single top cell)")
    parser.add_argument("-b", "--black-box", action="append", default=[], metavar="PATTERN",
                        help="leave cells matching the glob pattern out, keep only their pin shapes (repeatable)")
    parser.add_argument("-k", "--keep", action="append", default=[], metavar="PATTERN",
                        help="read cells matching the glob pattern although a -b pattern matches them (repeatable)")
    parser.add_argument("-n", "--net", action="append", default=[], metavar="PATTERN",
                        help="report only nets with a label matching the glob pattern (repeatable)")
    parser.add_argument("-w", "--workdir", default=".", metavar="DIR",
                        help="directory for the report and the marker database (default: current directory)")
    parser.add_argument("--strict", action="store_true",
                        help="exit with 1 when a net-opening cut has room for a second cut")
    args = parser.parse_args()
    as_json = args.json

    stack = sak_tech.stack(args.tech)
    if stack is None:
        known = ", ".join(sorted(sak_tech.STACKS))
        sak_json.fail(TOOL, f"No metal stack for PDK '{args.tech}' (known: {known})", as_json, sak_json.EXIT_USAGE)
    try:
        inputs = [sak_json.input_entry(args.layout)]
        layout = sak_netgraph.read_layout(args.layout)
        top = sak_netgraph.pick_top(layout, args.cell, args.layout)
    except (sak_json.InputError, sak_netgraph.LayoutError) as exc:
        sak_json.fail(TOOL, str(exc), as_json)
    if not os.path.isdir(args.workdir):
        sak_json.fail(TOOL, f"Work directory {args.workdir} does not exist", as_json, sak_json.EXIT_USAGE)

    start = time.time()
    ext = sak_netgraph.Extraction(layout, top, stack, args.black_box, args.keep)
    findings, nets = analyse(ext, args.net)
    body = summary_body(findings, ext, nets)
    body.update({"cell": top.name, "pdk": sak_tech.tech_key(args.tech), "black_box": args.black_box,
                 "keep": args.keep, "nets": args.net, "seconds": round(time.time() - start, 1)})

    stem = os.path.join(args.workdir, f"{top.name}_via_redundancy")
    header = [f"Via redundancy of {top.name} in {args.layout} (PDK {body['pdk']}, {body['seconds']} s)"]
    if args.black_box:
        header.append(f"Black boxes: {' '.join(args.black_box)}" + (f", kept: {' '.join(args.keep)}"
                                                                     if args.keep else ""))
    if args.net:
        header.append(f"Nets: {' '.join(args.net)}")
    with open(stem + ".rpt", "w", encoding="utf-8") as fh:
        fh.write("\n".join(report_lines(body, findings, 0, header)) + "\n")
    write_markers(stem + ".lyrdb", ext, findings)
    body["report"] = stem + ".rpt"
    body["markers"] = stem + ".lyrdb"
    body["findings"] = sak_json.cap([{k: v for k, v in f.items() if k not in ("cut", "box")} for f in findings],
                                    args.max)
    body["cap"] = args.max

    status = "ok"
    code = sak_json.EXIT_OK
    if args.strict and body["with_room"]:
        status = "findings"
        code = sak_json.EXIT_FINDINGS
    text = "\n".join(report_lines(body, findings, args.max, header)
                     + [f"Report: {body['report']}", f"Markers: {body['markers']}"])
    sak_json.emit(TOOL, status, inputs, body, as_json, text)
    sys.exit(code)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
