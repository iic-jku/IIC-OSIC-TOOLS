#!/usr/bin/env python3
# ========================================================================
# Summarize DRC and LVS reports for agents and scripts
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
# Usage: sak-report.py [--json] [--max <n>] [--newer-than <file>] <report>...
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

"""Summarize DRC or LVS reports as short text or as one JSON object.

Supported report formats, detected from the content and not from the name:

  - ``lyrdb``: KLayout report database (XML with a ``report-database`` root,
    also the sky130 ``.xml`` reports)
  - ``magic``: the text report written by ``sak-drc.sh`` for Magic
  - ``lvsdb``: KLayout LVS database (``#%lvsdb-klayout``)
  - ``netgen``: the Netgen LVS report (``*.lvs.out``) written by ``sak-lvs.sh``

One call summarizes DRC reports or LVS reports, not both.

Exit codes: 0 no violations or matching netlists, 1 violations or mismatch,
2 report missing, unreadable, truncated or older than ``--newer-than``,
3 wrong usage (including DRC and LVS reports in one call).
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sak_json  # noqa: E402

TOOL = "sak-report"

# KLayout provides the same API as the module 'pya' (the name used inside
# KLayout itself) as 'klayout.db', and the report database as 'klayout.rdb'.
try:
    import pya
except ImportError:
    try:
        import klayout.db as pya
        import klayout.rdb as _rdb
        pya.ReportDatabase = _rdb.ReportDatabase
    except ImportError:
        pya = None

DASHES = re.compile(r"^-{10,}\s*$")
MARKER = re.compile(r"^\s*(-?[\d.]+)um\s+(-?[\d.]+)um\s+(-?[\d.]+)um\s+(-?[\d.]+)um\s*$")
COUNT = re.compile(r"^\[INFO\] COUNT:\s*(\d+)\s*$")
NETGEN_COUNT = re.compile(r"^Number of (devices|nets):\s*(\d+)[^|]*\|Number of \1:\s*(\d+)")
NETGEN_HEAD = re.compile(r"^(Contents of circuit 1:|Circuit 1 cell )", re.M)
NETGEN_PROPERTY = ("Property errors were found.", "The following cells had property errors:")
GDSCHECK_GENERATOR = re.compile(r"<generator>\s*gdscheck\s*</generator>")
KIND = {"lyrdb": "drc", "magic": "drc", "lvsdb": "lvs", "netgen": "lvs"}


def detect_format(path: str) -> str:
    """Return the report format of ``path``, judged from its content."""
    try:
        with open(path, "rb") as f:
            head = f.read(4096).decode("utf-8", errors="replace")
    except OSError as exc:
        raise sak_json.InputError(f"cannot read {path}: {exc.strerror}") from exc
    if head.startswith("#%lvsdb-klayout"):
        return "lvsdb"
    if NETGEN_HEAD.search(head):
        return "netgen"
    if re.search(r"<report-database[\s>]", head):
        return "lyrdb"
    if any(DASHES.match(line) for line in head.splitlines()):
        return "magic"
    raise sak_json.InputError(f"{path}: unknown report format")


def detect_engine(path: str, fmt: str) -> str:
    """Name of the tool that wrote the report. gdscheck names itself in the generator tag of its lyrdb, every other lyrdb or lvsdb is KLayout's."""
    if fmt == "magic":
        return "magic"
    if fmt == "netgen":
        return "netgen"
    if fmt == "lyrdb":
        with open(path, "rb") as f:
            head = f.read(4096).decode("utf-8", errors="replace")
        if GDSCHECK_GENERATOR.search(head):
            return "gdscheck"
    return "klayout"


def value_bbox(value):
    """Bounding box in um of a geometric report value, None otherwise."""
    for test, get in (("is_box", "box"), ("is_polygon", "polygon"),
                      ("is_path", "path"), ("is_edge", "edge"),
                      ("is_edge_pair", "edge_pair")):
        if getattr(value, test)():
            geom = getattr(value, get)()
            box = geom if test == "is_box" else geom.bbox()
            return [box.left, box.bottom, box.right, box.top]
    return None


def category_name(cat) -> str:
    """Rule name of a category, sub categories joined with dots (path() quotes dotted names)."""
    names = []
    while cat is not None:
        names.append(cat.name())
        cat = cat.parent()
    return ".".join(reversed(names))


def read_lyrdb(path: str) -> dict:
    if pya is None:
        raise sak_json.InputError("KLayout Python module not found (tried 'pya' and 'klayout.db')")
    rdb = pya.ReportDatabase("sak-report")
    try:
        rdb.load(path)
    except Exception as exc:
        raise sak_json.InputError(f"{path}: {exc}") from exc
    rules = {}
    top = rdb.top_cell_name
    for item in rdb.each_item():
        cat = rdb.category_by_id(item.category_id())
        name = category_name(cat)
        rule = rules.get(name)
        if rule is None:
            rule = rules[name] = {"rule": name, "description": cat.description,
                                  "count": 0, "markers": []}
        bbox = None
        for value in item.each_value():
            bbox = value_bbox(value)
            if bbox is not None:
                break
        cell = rdb.cell_by_id(item.cell_id()).name()
        rule["count"] += 1
        rule["markers"].append({"cell": cell, "bbox_um": bbox})
    if not top:
        cells = [c.name() for c in rdb.each_cell()]
        top = cells[0] if cells else ""
    return {"format": "lyrdb", "top_cell": top, "rules": list(rules.values())}


def read_magic(path: str) -> dict:
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError as exc:
        raise sak_json.InputError(f"cannot read {path}: {exc.strerror}") from exc
    # layout: cell name, dashes, then per rule: text, dashes, markers, dashes
    if len(lines) < 2 or not DASHES.match(lines[1]):
        raise sak_json.InputError(f"{path}: not a Magic DRC report")
    top = lines[0].strip()
    rules = []
    declared = None
    i = 2
    while i < len(lines):
        line = lines[i]
        m = COUNT.match(line)
        if m:
            declared = int(m.group(1))
            break
        if line.startswith("[INFO]") or not line.strip():
            i += 1
            continue
        if i + 1 < len(lines) and DASHES.match(lines[i + 1]):
            rule = {"rule": line.strip(), "description": line.strip(), "count": 0, "markers": []}
            i += 2
            while i < len(lines) and not DASHES.match(lines[i]):
                m = MARKER.match(lines[i])
                if m:
                    rule["markers"].append({"cell": top, "bbox_um": [float(g) for g in m.groups()]})
                i += 1
            rule["count"] = len(rule["markers"])
            rules.append(rule)
        i += 1
    if declared is None:
        raise sak_json.InputError(f"{path}: no final COUNT line, the DRC run did not finish")
    found = sum(r["count"] for r in rules)
    if declared != found:
        raise sak_json.InputError(f"{path}: COUNT is {declared} but {found} markers were read")
    return {"format": "magic", "top_cell": top, "rules": rules}


def _get(obj, attr):
    """Attribute of a KLayout object, called if it is a method (the API differs between 'pya' and 'klayout.db')."""
    value = getattr(obj, attr)
    return value() if callable(value) else value


def _name(obj, *attrs) -> str:
    """First non-empty name attribute of a KLayout netlist object, '' for none."""
    if obj is None:
        return ""
    for attr in attrs:
        value = _get(obj, attr)
        if value:
            return str(value)
    return ""


def read_lvsdb(path: str) -> dict:
    if pya is None:
        raise sak_json.InputError("KLayout Python module not found (tried 'pya' and 'klayout.db')")
    lvs = pya.LayoutVsSchematic()
    sak_json.KEEP_ALIVE.append(lvs)  # see sak_json.KEEP_ALIVE
    try:
        lvs.read(path)
    except Exception as exc:
        raise sak_json.InputError(f"{path}: {exc}") from exc
    xref = lvs.xref()
    pairs = list(xref.each_circuit_pair())
    if not pairs:
        raise sak_json.InputError(f"{path}: no circuits compared, the LVS run did not finish")
    top = lvs.netlist().top_circuit()
    top_name = _name(top, "name")
    # the pair of the top circuit, the first pair if the top circuit has no partner
    pair = next((p for p in pairs if _name(_get(p, "first"), "name") == top_name), pairs[0])
    layout, schem = _get(pair, "first"), _get(pair, "second")
    ok = (pya.NetlistCrossReference.Match, pya.NetlistCrossReference.MatchWithWarning)
    match = layout is not None and schem is not None and _get(pair, "status") in ok

    def counts(circuit):
        if circuit is None:
            return {"devices": 0, "nets": 0}
        return {"devices": len(list(circuit.each_device())), "nets": len(list(circuit.each_net()))}

    unmatched = {"nets": [], "devices": [], "pins": []}
    for key, each, attrs in (("nets", xref.each_net_pair, ("expanded_name",)),
                             ("devices", xref.each_device_pair, ("expanded_name",)),
                             ("pins", xref.each_pin_pair, ("name",))):
        for p in list(each(pair)):
            if _get(p, "status") in ok:
                continue
            for side, obj in (("layout", _get(p, "first")), ("schematic", _get(p, "second"))):
                if obj is not None:
                    unmatched[key].append({"side": side, "name": _name(obj, *attrs)})
    return {"kind": "lvs", "format": "lvsdb", "top_cell": top_name or _name(layout, "name"),
            "match": match, "layout": counts(layout), "schematic": counts(schem),
            "property_errors": False, "unmatched_available": True, "unmatched": unmatched}


def read_netgen(path: str) -> dict:
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError as exc:
        raise sak_json.InputError(f"cannot read {path}: {exc.strerror}") from exc
    # same verdict as sak-lvs.sh: only this exact line passes, property errors fail
    finals = [ln for ln in lines if ln.startswith("Final result:")]
    if not finals:
        raise sak_json.InputError(f"{path}: no 'Final result:' line, the LVS run did not finish")
    property_errors = any(ln.startswith(NETGEN_PROPERTY) for ln in lines)
    match = finals[-1] == "Final result: Circuits match uniquely." and not property_errors
    layout = {"devices": None, "nets": None}
    schem = {"devices": None, "nets": None}
    top = ""
    for i, line in enumerate(lines):
        m = NETGEN_COUNT.match(line)
        if m:
            layout[m.group(1)] = int(m.group(2))
            schem[m.group(1)] = int(m.group(3))
        elif line.startswith("Circuit 1:") and "|Circuit 2:" in line:
            top = line[len("Circuit 1:"):line.index("|")].strip()
    # circuit 1 is the layout, circuit 2 the schematic (see the netgen call in sak-lvs.sh)
    return {"kind": "lvs", "format": "netgen", "top_cell": top, "match": match,
            "layout": layout, "schematic": schem, "property_errors": property_errors,
            "unmatched_available": False, "unmatched": {"nets": [], "devices": [], "pins": []}}


READERS = {"lyrdb": read_lyrdb, "magic": read_magic, "lvsdb": read_lvsdb, "netgen": read_netgen}


def summarize(path: str, limit: int) -> dict:
    fmt = detect_format(path)
    reader = READERS.get(fmt)
    if reader is None:
        raise sak_json.InputError(f"{path}: unsupported report format {fmt}")
    rep = reader(path)
    engine = detect_engine(path, fmt)
    if rep.get("kind") == "lvs":
        counts = {key: len(items) for key, items in rep["unmatched"].items()}
        rep["unmatched"] = {key: sak_json.cap(items, limit) for key, items in rep["unmatched"].items()}
        return {"path": path, "engine": engine, **rep, "unmatched_count": counts}
    rules = sorted(rep["rules"], key=lambda r: -r["count"])
    for rule in rules:
        rule["markers"] = sak_json.cap(rule["markers"], limit)
    return {"path": path, "engine": engine, "format": rep["format"], "top_cell": rep["top_cell"],
            "total": sum(r["count"] for r in rules), "rules": rules}


def lvs_text_summary(reports: list, match: bool) -> str:
    out = [f"LVS {'match' if match else 'MISMATCH'} in {len(reports)} report(s)"]
    for rep in reports:
        lay, sch = rep["layout"], rep["schematic"]
        out.append(f"{rep['path']} ({rep['engine']} {rep['format']}, top cell {rep['top_cell']}): "
                   f"{'match' if rep['match'] else 'mismatch'}, "
                   f"devices {lay['devices']}/{sch['devices']}, nets {lay['nets']}/{sch['nets']} (layout/schematic)")
        if rep["property_errors"]:
            out.append("  property errors found")
        for key, items in rep["unmatched"].items():
            if rep["unmatched_count"][key]:
                names = ", ".join(f"{i['name']} ({i['side']})" for i in items)
                out.append(f"  unmatched {key}: {rep['unmatched_count'][key]}: {names}")
    return "\n".join(out)


def text_summary(reports: list, total: int) -> str:
    out = [f"{total} DRC violation(s) in {len(reports)} report(s)"]
    for rep in reports:
        out.append(f"{rep['path']} ({rep['engine']} {rep['format']}, top cell {rep['top_cell']}): {rep['total']}")
        for rule in rep["rules"]:
            out.append(f"  {rule['rule']}: {rule['count']}")
    return "\n".join(out)


def main() -> None:
    parser = sak_json.SakArgumentParser(
        prog="sak-report.py", tool=TOOL, description="Summarize DRC reports (KLayout lyrdb, Magic) or LVS reports (KLayout lvsdb, Netgen).")
    parser.add_argument("--newer-than", metavar="FILE",
                        help="fail if a report is older than FILE (stale report)")
    parser.add_argument("reports", nargs="+", metavar="report")
    args = parser.parse_args()
    as_json = args.json

    try:
        inputs = [sak_json.input_entry(p) for p in args.reports]
        if args.newer_than:
            ref = os.stat(args.newer_than).st_mtime if os.path.exists(args.newer_than) else None
            if ref is None:
                raise sak_json.InputError(f"cannot read {args.newer_than}: No such file or directory")
            for p in args.reports:
                if os.stat(p).st_mtime < ref:
                    raise sak_json.InputError(f"{p} is older than {args.newer_than}")
        kinds = {KIND.get(detect_format(p)) for p in args.reports}
        if len(kinds) > 1:
            sak_json.fail(TOOL, "DRC and LVS reports cannot be summarized in one call",
                          as_json, sak_json.EXIT_USAGE)
        reports = [summarize(p, args.max) for p in args.reports]
    except sak_json.InputError as exc:
        sak_json.fail(TOOL, str(exc), as_json)

    if kinds == {"lvs"}:
        match = all(r["match"] for r in reports)
        body = {"kind": "lvs", "match": match, "cap": args.max, "reports": reports}
        sak_json.emit(TOOL, "clean" if match else "findings", inputs, body, as_json,
                      lvs_text_summary(reports, match))
        sys.exit(sak_json.EXIT_OK if match else sak_json.EXIT_FINDINGS)

    total = sum(r["total"] for r in reports)
    status = "clean" if total == 0 else "findings"
    body = {"kind": "drc", "total": total, "cap": args.max, "reports": reports}
    sak_json.emit(TOOL, status, inputs, body, as_json, text_summary(reports, total))
    sys.exit(sak_json.EXIT_OK if total == 0 else sak_json.EXIT_FINDINGS)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
