#!/usr/bin/env python3
# ========================================================================
# Layout XOR script using KLayout
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
# Usage: sak-gds-xor.py [-d] [-H] [-o <output>] [-c <cellname>]
#                       <layout A> <layout B>
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

"""XOR two layouts and write the differing geometry to an output layout.

Both input layouts are read, one top cell of each is selected (either the
single top cell, or the cell given via ``-c``), and the flattened geometry
of the two cells is compared layer by layer. The union of all layer/datatype
pairs occurring in either layout is considered, so a layer present in only
one of the two files shows up completely as a difference.

The differing geometry is written to the output layout (default
``xor_result.gds``) into a cell named ``XOR_<cellname>``, on the same
layer/datatype as the difference occurred. Loading that file on top of the
compared layouts in KLayout highlights where the two differ.

GDS2 and OASIS (optionally gzipped) are read and written; the format is
picked from the file extension, as usual for KLayout.

Notes:

  - Differing database units are handled: layout B is scaled to the
    database unit of layout A, which is also the database unit of the
    output layout.
  - Layers referenced by name only (no layer/datatype number) cannot be
    matched between layouts and are skipped (reported with ``-d``).
  - ``-H`` switches KLayout to deep (hierarchical) mode, which is much
    faster and needs far less memory on large, hierarchical layouts. The
    resulting difference geometry is written out flat in either case.
    Deep mode splits the geometry along the cell hierarchy, so it reports
    a higher polygon count than flat mode; the differing area, which is
    the meaningful number, is identical.

Usage:
    sak-gds-xor.py [-d] [-H] [-o <output>] [-c <cellname>]
                   <layout A> <layout B>

Return codes for script automation:
  0 = no differences found
  1 = differences found
  2 = error (bad arguments, file or cell not found, ...)
"""

import argparse
import os
import sys

ERR_NONE = 0
ERR_DIFF = 1
ERR_FAIL = 2

# KLayout provides the same API as the module 'pya' (the name used inside
# the KLayout application) and as the standalone module 'klayout.db'. The
# container puts $TOOLS/klayout/pymod on PYTHONPATH, so 'pya' works from a
# plain python3 as well as from 'klayout -zz -r'.
try:
    import pya
except ImportError:
    try:
        import klayout.db as pya
    except ImportError:
        print("[ERROR] KLayout Python module not found "
              "(tried 'pya' and 'klayout.db')!", file=sys.stderr)
        sys.exit(ERR_FAIL)


def die(msg: str) -> None:
    """Print an error message and terminate with the error return code."""
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(ERR_FAIL)


def read_layout(path: str) -> pya.Layout:
    """Read a layout file, aborting with a clear message on failure."""
    if not os.path.isfile(path):
        die(f"File {path} not found!")
    layout = pya.Layout()
    try:
        layout.read(path)
    except Exception as e:  # KLayout raises a plain RuntimeError here
        die(f"Cannot read {path}: {e}")
    return layout


def resolve_top_cell(layout: pya.Layout, path: str, name: str | None):
    """Return the cell to compare, either by name or as the single top cell.

    ``Layout.top_cell()`` raises when a layout has more than one top cell,
    which is a common situation (e.g. leftover cells in a library GDS), so
    ``top_cells()`` is used and the ambiguity is reported instead.
    """
    if name:
        cell = layout.cell(name)
        if cell is None:
            die(f"Cell '{name}' not found in {path}!")
        return cell
    tops = layout.top_cells()
    if not tops:
        die(f"No top cell found in {path}!")
    if len(tops) > 1:
        # A library GDS can have dozens of top cells, so only list a few.
        shown = [c.name for c in tops[:8]]
        if len(tops) > len(shown):
            shown.append("...")
        die(f"{path} has {len(tops)} top cells ({', '.join(shown)}); "
            f"select one with -c!")
    return tops[0]


def collect_layers(layout: pya.Layout, path: str,
                   debug: bool) -> set[tuple[int, int]]:
    """Collect all numbered layer/datatype pairs used in a layout.

    Layers carrying only a name (layer/datatype -1, e.g. from a CIF or DXF
    import) have no counterpart to match in the other layout and are
    skipped.
    """
    pairs = set()
    for li in layout.layer_indices():
        info = layout.get_info(li)
        if info.layer < 0 or info.datatype < 0:
            if debug:
                print(f"[INFO] Skipping named layer '{info.name}' in {path}.")
            continue
        pairs.add((info.layer, info.datatype))
    return pairs


def gds_xor(file_a: str, file_b: str, output: str, top_cell: str | None = None,
            hierarchical: bool = False, debug: bool = False) -> int:
    """XOR two layouts and write the differences to ``output``.

    Returns the total number of differing polygons.
    """
    layout_a = read_layout(file_a)
    layout_b = read_layout(file_b)

    cell_a = resolve_top_cell(layout_a, file_a, top_cell)
    cell_b = resolve_top_cell(layout_b, file_b, top_cell)

    print(f"[INFO] Layout A: {file_a} (cell '{cell_a.name}')")
    print(f"[INFO] Layout B: {file_b} (cell '{cell_b.name}')")

    if cell_a.name != cell_b.name:
        print(f"[WARNING] Comparing different cells "
              f"('{cell_a.name}' vs. '{cell_b.name}')!")

    # All geometry is handled in database units, so layout B has to be
    # scaled when the two layouts disagree on the database unit.
    scale = layout_b.dbu / layout_a.dbu
    do_scale = abs(scale - 1.0) > 1e-9
    if do_scale:
        print(f"[WARNING] Database units differ ({layout_a.dbu} um vs. "
              f"{layout_b.dbu} um), scaling layout B by {scale}!")

    out_layout = pya.Layout()
    out_layout.dbu = layout_a.dbu
    out_cell = out_layout.create_cell(f"XOR_{cell_a.name}")

    # Deep mode keeps the hierarchy during the boolean operations, which is
    # significantly faster and leaner on large layouts. Both regions have to
    # come from the same shape store to be combinable.
    dss = pya.DeepShapeStore() if hierarchical else None
    if debug and hierarchical:
        print("[INFO] Deep (hierarchical) mode is enabled.")

    def region_of(cell, layer_index):
        if layer_index is None:
            return pya.Region()
        shapes = cell.begin_shapes_rec(layer_index)
        return pya.Region(shapes, dss) if dss else pya.Region(shapes)

    layer_pairs = (collect_layers(layout_a, file_a, debug)
                   | collect_layers(layout_b, file_b, debug))

    diff_polygons = 0
    diff_layers = 0

    for layer_num, datatype in sorted(layer_pairs):
        region_a = region_of(cell_a, layout_a.find_layer(layer_num, datatype))
        region_b = region_of(cell_b, layout_b.find_layer(layer_num, datatype))
        if do_scale:
            region_b.transform(pya.ICplxTrans(scale))

        xor_region = region_a ^ region_b
        count = xor_region.count()

        if count == 0:
            if debug:
                print(f"[INFO] Layer {layer_num}/{datatype}: identical.")
            continue

        out_cell.shapes(out_layout.layer(layer_num, datatype)).insert(xor_region)
        area = xor_region.area() * out_layout.dbu * out_layout.dbu
        diff_polygons += count
        diff_layers += 1
        print(f"[INFO] Layer {layer_num}/{datatype}: {count} difference(s), "
              f"{area:.4f} um^2.")

    try:
        out_layout.write(output)
    except Exception as e:  # KLayout raises a plain RuntimeError here
        die(f"Cannot write {output}: {e}")

    if diff_polygons == 0:
        print(f"[DONE] No differences found, empty {output} written. Bye!")
    else:
        print(f"[DONE] {diff_polygons} difference(s) on {diff_layers} layer(s) "
              f"written to {output}. Bye!")

    return diff_polygons


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Layout XOR script using KLayout (ICD@JKU). "
                    "XORs two layouts and writes the differences to an "
                    "output layout.",
        epilog="Return codes: 0 = no differences, 1 = differences found, "
               "2 = error.")
    parser.add_argument("layout_a",
                        help="First layout (GDS2/OASIS, optionally gzipped)")
    parser.add_argument("layout_b",
                        help="Second layout (GDS2/OASIS, optionally gzipped)")
    parser.add_argument("-o", "--output", default="xor_result.gds",
                        help="Output layout file (default: xor_result.gds)")
    parser.add_argument("-c", "--cell", default=None,
                        help="Cell to compare (default: the single top cell)")
    parser.add_argument("-H", "--hierarchical", action="store_true",
                        help="Use deep (hierarchical) mode, faster on large "
                             "layouts")
    parser.add_argument("-d", "--debug", action="store_true",
                        help="Enable debug information")
    args = parser.parse_args()

    diff_polygons = gds_xor(args.layout_a, args.layout_b, args.output,
                            args.cell, args.hierarchical, args.debug)

    sys.exit(ERR_DIFF if diff_polygons > 0 else ERR_NONE)


if __name__ == "__main__":
    main()
