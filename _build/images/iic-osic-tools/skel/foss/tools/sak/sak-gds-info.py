#!/usr/bin/env python3
# ========================================================================
# Layout facts (layers, bounding box, cell tree, labels) as text or JSON
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
# Usage: sak-gds-info.py [--json] [--max <n>] [-t <pdk>] [-c <cell>] [--depth <n>]
#                        [--bbox x1,y1,x2,y2] [--layers] [--cells] [--labels] <layout>
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

"""Report facts about a layout: layers, bounding box, cell tree and labels.

The layout (GDS2 or OASIS, optionally gzipped) is read and one top cell is
selected (the single top cell, or the cell given with ``-c``). Without a part
option (``--layers``, ``--cells``, ``--labels``) all three parts are reported.

  - Layers: shape count and bounding box per layer/datatype, with the layer
    name of the PDK given with ``-t`` (default ``$PDK``, ``null`` if unknown).
    The shape count of the whole cell is computed from the number of flat
    placements of every cell, so the shapes of a full chip are not iterated.
    With ``--bbox`` only the shapes touching the region (in um) are counted.
  - Cells: the instance tree below the selected cell, children grouped by cell
    name with their instance count, down to ``--depth`` levels (default 2).
  - Labels: the text labels with layer and position in um.

Exit codes: 0 success, 2 layout missing or unreadable, 3 wrong usage
(including a layout with several top cells and no ``-c``).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # noqa: E402
import sak_tech  # noqa: E402

TOOL = "sak-gds-info"

# KLayout provides the same API as the module 'pya' (inside the application)
# and as 'klayout.db' (standalone). The container puts the pymod directory of
# KLayout on PYTHONPATH, so 'pya' works from a plain python3.
try:
    import pya
except ImportError:
    try:
        import klayout.db as pya
    except ImportError:
        sak_json.fail(TOOL, "KLayout Python module not found (tried 'pya' and 'klayout.db')",
                      "--json" in sys.argv[1:])


def um(value: float) -> float:
    """A length in um without floating point noise from the database unit."""
    return round(value, 6)


def box_um(box) -> list:
    """[x1, y1, x2, y2] in um of a DBox."""
    return [um(box.left), um(box.bottom), um(box.right), um(box.top)]


def parse_region(text: str):
    """A DBox from 'x1,y1,x2,y2' in um, None if the text is malformed or holds nan or inf."""
    try:
        x1, y1, x2, y2 = (float(v) for v in text.split(","))
    except ValueError:
        return None
    if not all(math.isfinite(v) for v in (x1, y1, x2, y2)):
        return None
    return pya.DBox(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))


def placements(layout, top) -> dict:
    """Number of flat placements of every cell under ``top`` (cell index -> count), array sizes multiplied down."""
    count = {top.cell_index(): 1}
    for index in layout.each_cell_top_down():
        n = count.get(index, 0)
        if n == 0:
            continue
        for inst in layout.cell(index).each_inst():
            child = inst.cell_index
            count[child] = count.get(child, 0) + n * inst.size()
    return count


def layer_facts(layout, top, names: dict, region, limit: int) -> tuple:
    """(layers, total) with shape count, bounding box and PDK name per layer/datatype."""
    counts = None if region else placements(layout, top)
    layers = []
    for li in layout.layer_indexes():
        info = layout.get_info(li)
        if region:
            iterator = top.begin_shapes_rec_touching(li, region.to_itype(layout.dbu))
            shapes = 0
            bbox = pya.DBox()
            while not iterator.at_end():
                shapes += 1
                bbox += (iterator.dtrans() * iterator.shape().dbbox())
                iterator.next()
        else:
            shapes = sum(layout.cell(ci).shapes(li).size() * n for ci, n in counts.items())
            bbox = top.dbbox_per_layer(li)
        if shapes == 0:
            continue
        layers.append({"layer": info.layer, "datatype": info.datatype,
                       "name": names.get((info.layer, info.datatype)),
                       "shapes": shapes, "bbox_um": box_um(bbox)})
    layers.sort(key=lambda entry: (entry["layer"], entry["datatype"]))
    return sak_json.cap(layers, limit), len(layers)


def cell_tree(layout, cell, instances: int, depth: int, limit: int) -> dict:
    """The instance tree below ``cell``, children grouped by name and sorted by name."""
    node = {"name": cell.name, "instances": instances, "children": []}
    grouped = {}
    for inst in cell.each_inst():
        name = layout.cell(inst.cell_index).name
        grouped[name] = (layout.cell(inst.cell_index), grouped.get(name, (None, 0))[1] + inst.size())
    if depth <= 0:
        if grouped:
            node["children_hidden"] = len(grouped)
        return node
    children = [cell_tree(layout, child, n, depth - 1, limit) for _, (child, n) in sorted(grouped.items())]
    node["children"] = sak_json.cap(children, limit)
    if len(children) > len(node["children"]):
        node["children_total"] = len(children)
    return node


def label_facts(layout, top, region, limit: int) -> tuple:
    """(labels, total): text labels with layer and position in um, at most ``limit`` of them."""
    labels = []
    total = 0
    for li in layout.layer_indexes():
        info = layout.get_info(li)
        if region:
            iterator = top.begin_shapes_rec_touching(li, region.to_itype(layout.dbu))
        else:
            iterator = top.begin_shapes_rec(li)
        iterator.shape_flags = pya.Shapes.STexts
        while not iterator.at_end():
            total += 1
            if limit == 0 or len(labels) < limit:
                text = iterator.shape().dtext
                pos = iterator.dtrans() * pya.DPoint(text.x, text.y)
                labels.append({"text": text.string, "layer": info.layer, "datatype": info.datatype,
                               "x_um": um(pos.x), "y_um": um(pos.y)})
            iterator.next()
    return labels, total


def pick_top(layout, path: str, name, as_json: bool):
    """The cell to report: the one named ``name`` or the single top cell."""
    tops = sorted(c.name for c in layout.top_cells())
    if name:
        cell = layout.cell(name)
        if cell is None:
            sak_json.fail(TOOL, f"Cell '{name}' not found in {path}", as_json, sak_json.EXIT_USAGE,
                          {"top_cells": tops})
        return cell, tops
    if not tops:
        sak_json.fail(TOOL, f"No top cell found in {path}", as_json, sak_json.EXIT_INPUT)
    if len(tops) > 1:
        sak_json.fail(TOOL, f"{path} has {len(tops)} top cells, select one with -c", as_json,
                      sak_json.EXIT_USAGE, {"top_cells": tops})
    return layout.cell(tops[0]), tops


def tree_text(node: dict, indent: int = 0) -> list:
    """Indented text lines of the cell tree."""
    count = "" if indent == 0 else f" x{node['instances']}"
    lines = [f"{'  ' * indent}{node['name']}{count}"]
    for child in node["children"]:
        lines += tree_text(child, indent + 1)
    return lines


def text_summary(body: dict) -> str:
    """Short text for a person."""
    lines = [f"Cell {body['cell']}, dbu {body['dbu']} um, bbox (um) {body['bbox_um']}"]
    if len(body["top_cells"]) > 1:
        lines.append(f"Top cells: {', '.join(body['top_cells'])}")
    if "layers" in body:
        lines.append(f"Layers ({body['layers_total']}):")
        for entry in body["layers"]:
            name = entry["name"] or "-"
            lines.append(f"  {entry['layer']}/{entry['datatype']} {name}: {entry['shapes']} shapes, "
                         f"bbox {entry['bbox_um']}")
    if "cells" in body:
        lines.append("Cells:")
        lines += ["  " + line for line in tree_text(body["cells"])]
    if "labels" in body:
        lines.append(f"Labels ({body['labels_total']}):")
        for entry in body["labels"]:
            lines.append(f"  {entry['text']} on {entry['layer']}/{entry['datatype']} at "
                         f"({entry['x_um']}, {entry['y_um']})")
    return "\n".join(lines)


def main() -> None:
    """Read the layout and print the requested facts."""
    parser = sak_json.SakArgumentParser(tool=TOOL, description="Report layers, bounding box, cell tree and labels "
                                        "of a layout.")
    parser.add_argument("layout", help="GDS2 or OASIS layout (optionally gzipped)")
    parser.add_argument("-t", "--tech", default=os.getenv("PDK"), metavar="PDK",
                        help="PDK for the layer names (default: environment variable PDK)")
    parser.add_argument("-c", "--cell", metavar="CELL", help="cell to report (default: the single top cell)")
    parser.add_argument("--depth", type=int, default=2, metavar="N", help="levels of the cell tree (default: 2)")
    parser.add_argument("--bbox", metavar="X1,Y1,X2,Y2", help="count only the shapes touching this region (um)")
    parser.add_argument("--layers", action="store_true", help="report the layers")
    parser.add_argument("--cells", action="store_true", help="report the cell tree")
    parser.add_argument("--labels", action="store_true", help="report the text labels")
    args = parser.parse_args()

    region = None
    if args.bbox:
        region = parse_region(args.bbox)
        if region is None:
            parser.error("--bbox needs four finite numbers: x1,y1,x2,y2")
    if args.depth < 0:
        parser.error("--depth must not be negative")
    parts = [args.layers, args.cells, args.labels]
    if not any(parts):
        parts = [True, True, True]

    as_json = args.json
    try:
        inputs = [sak_json.input_entry(args.layout)]
    except sak_json.InputError as exc:
        sak_json.fail(TOOL, str(exc), as_json)
    layout = pya.Layout()
    try:
        layout.read(args.layout)
    except Exception as exc:  # KLayout raises a plain RuntimeError  # pylint: disable=broad-except
        sak_json.fail(TOOL, f"Cannot read {args.layout}: {exc}", as_json)
    top, tops = pick_top(layout, args.layout, args.cell, as_json)

    body = {"cell": top.name, "top_cells": tops, "dbu": layout.dbu, "bbox_um": box_um(top.dbbox()),
            "cap": args.max}
    if region:
        body["region_um"] = box_um(region)
    if parts[0]:
        pdk_root = os.getenv("PDK_ROOT", "/foss/pdks")
        names = sak_tech.layer_names(args.tech, pdk_root) if args.tech else {}
        body["layers"], body["layers_total"] = layer_facts(layout, top, names, region, args.max)
    if parts[1]:
        body["cells"] = cell_tree(layout, top, 1, args.depth, args.max)
    if parts[2]:
        body["labels"], body["labels_total"] = label_facts(layout, top, region, args.max)
    sak_json.emit(TOOL, "ok", inputs, body, as_json, text_summary(body))


if __name__ == "__main__":
    sak_json.run(TOOL, main)
