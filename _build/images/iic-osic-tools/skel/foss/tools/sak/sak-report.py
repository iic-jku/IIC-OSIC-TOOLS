#!/usr/bin/env python3
# ========================================================================
# Summarize DRC reports (KLayout lyrdb, Magic) for agents and scripts
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

"""Summarize DRC reports as short text or as one JSON object.

Supported report formats, detected from the content and not from the name:

  - ``lyrdb``: KLayout report database (XML with a ``report-database`` root,
    also the sky130 ``.xml`` reports)
  - ``magic``: the text report written by ``sak-drc.sh`` for Magic

Exit codes: 0 no violations, 1 violations, 2 report missing, unreadable,
truncated or older than ``--newer-than``, 3 wrong usage.
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


def detect_format(path: str) -> str:
    """Return the report format of ``path``, judged from its content."""
    try:
        with open(path, "rb") as f:
            head = f.read(4096).decode("utf-8", errors="replace")
    except OSError as exc:
        raise sak_json.InputError(f"cannot read {path}: {exc.strerror}") from exc
    if re.search(r"<report-database[\s>]", head):
        return "lyrdb"
    if any(DASHES.match(line) for line in head.splitlines()):
        return "magic"
    raise sak_json.InputError(f"{path}: unknown report format")


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


READERS = {"lyrdb": read_lyrdb, "magic": read_magic}
# Task 2 adds the LVS formats here, an unknown format is an input error.


def summarize(path: str, limit: int) -> dict:
    fmt = detect_format(path)
    reader = READERS.get(fmt)
    if reader is None:
        raise sak_json.InputError(f"{path}: unsupported report format {fmt}")
    rep = reader(path)
    rules = sorted(rep["rules"], key=lambda r: -r["count"])
    for rule in rules:
        rule["markers"] = sak_json.cap(rule["markers"], limit)
    return {"path": path, "format": rep["format"], "top_cell": rep["top_cell"],
            "total": sum(r["count"] for r in rules), "rules": rules}


def text_summary(reports: list, total: int) -> str:
    out = [f"{total} DRC violation(s) in {len(reports)} report(s)"]
    for rep in reports:
        out.append(f"{rep['path']} ({rep['format']}, top cell {rep['top_cell']}): {rep['total']}")
        for rule in rep["rules"]:
            out.append(f"  {rule['rule']}: {rule['count']}")
    return "\n".join(out)


def main() -> None:
    parser = sak_json.SakArgumentParser(
        prog="sak-report.py", tool=TOOL, description="Summarize DRC reports (KLayout lyrdb, Magic).")
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
        reports = [summarize(p, args.max) for p in args.reports]
    except sak_json.InputError as exc:
        sak_json.fail(TOOL, str(exc), as_json)

    total = sum(r["total"] for r in reports)
    status = "clean" if total == 0 else "findings"
    body = {"kind": "drc", "total": total, "cap": args.max, "reports": reports}
    sak_json.emit(TOOL, status, inputs, body, as_json, text_summary(reports, total))
    sys.exit(sak_json.EXIT_OK if total == 0 else sak_json.EXIT_FINDINGS)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
