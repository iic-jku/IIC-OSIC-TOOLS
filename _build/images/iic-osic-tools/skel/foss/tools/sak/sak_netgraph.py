#!/usr/bin/env python3
# ========================================================================
# Nets of a layout as graphs of conductor polygons joined by cuts
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
# Imported by sak-via-redundancy.py and sak-current-density.py (not a command itself).
#
# This module uses KLayout (https://www.klayout.de).
# ========================================================================

"""Nets of a layout as graphs of conductor polygons joined by cuts.

The conductors and cuts of the metal stack in ``sak_tech.STACKS`` are read flat from one top cell. Each conductor is
merged, and every merged polygon is a node. Every cut shape (merged first, so a cut drawn twice by two abutting cells
counts once) is an edge from the node under its center on its lower conductor to the node on its upper conductor.
The connected parts of this graph are the nets.

Terminals are the nodes where a net meets a device or the outside:

  - device terminals: diffusion, gates, resistor heads, cap plates, and polygons touching a device body
  - polygons that carry a label of the top cell
  - pads: polygons of the pad conductor under a passivation opening
  - pin shapes of black-box instances

A black-box cell is not read. Only its pin shapes (the pin datatype, named by the label inside them) are added to
the conductors at every instance, so the wiring of the parent still connects to them.
"""

import fnmatch
import math
from collections import defaultdict

try:
    import pya
except ImportError:
    import klayout.db as pya


class LayoutError(Exception):
    """The layout cannot be read or has no usable top cell."""


def read_layout(path: str):
    """Read a GDS2 or OASIS file (optionally gzipped)."""
    layout = pya.Layout()
    try:
        layout.read(path)
    except Exception as exc:  # KLayout raises a plain RuntimeError  # pylint: disable=broad-except
        raise LayoutError(f"cannot read {path}: {exc}") from exc
    return layout


def pick_top(layout, name: str | None, path: str):
    """The cell named ``name``, or the single top cell."""
    tops = sorted(c.name for c in layout.top_cells())
    if name:
        cell = layout.cell(name)
        if cell is None:
            raise LayoutError(f"cell '{name}' not found in {path} (top cells: {', '.join(tops)})")
        return cell
    if len(tops) != 1:
        raise LayoutError(f"{path} has {len(tops)} top cells ({', '.join(tops)}), select one with -c")
    return layout.cell(tops[0])


class _Index:
    """Point location in the trapezoids of many polygons, with buckets on a square grid."""

    def __init__(self, bucket: int):
        self.bucket = bucket
        self.cells = defaultdict(list)

    def add(self, owner: int, trap) -> None:
        box = trap.bbox()
        entry = (owner, box.left, box.bottom, box.right, box.top, None if trap.is_box() else trap)
        b = self.bucket
        for ix in range(box.left // b, box.right // b + 1):
            for iy in range(box.bottom // b, box.top // b + 1):
                self.cells[(ix, iy)].append(entry)

    def find(self, x: int, y: int) -> int:
        """The owner of the trapezoid holding the point (edges included), -1 if none."""
        point = None
        for owner, x1, y1, x2, y2, trap in self.cells.get((x // self.bucket, y // self.bucket), ()):
            if x1 <= x <= x2 and y1 <= y <= y2:
                if trap is None:
                    return owner
                if point is None:
                    point = pya.Point(x, y)
                if trap.inside(point):
                    return owner
        return -1


def inner_point(poly) -> tuple[int, int]:
    """A point inside a polygon: the center of its first trapezoid."""
    traps = poly.decompose_trapezoids(pya.Polygon.TD_htrapezoids)
    box = (traps[0] if traps else poly).bbox()
    return box.center().x, box.center().y


class Net:
    """One connected part of the graph: its nodes, its cuts and its name."""

    __slots__ = ("index", "name", "nodes", "cuts", "labels", "pads", "pins")

    def __init__(self, index: int):
        self.index = index
        self.name = ""
        self.nodes: list[int] = []
        self.cuts: list[int] = []
        self.labels: list[str] = []
        self.pads: list[int] = []
        self.pins: list[int] = []


class Extraction:
    """The conductor polygons, cuts, terminals and nets of one top cell.

    Nodes are numbered over all conductors: ``node_cond[n]`` is the conductor index, ``node_poly[n]`` the merged
    polygon (database units), ``node_traps[n]`` its trapezoids. ``node_terms[n]`` lists the terminals on it as
    ``(kind, name)`` with kind ``device``, ``label``, ``pad`` or ``pin``. Cuts are numbered over all cut layers.
    """

    def __init__(self, layout, top, stack: dict, black_box=(), keep=(), bucket_um: float = 5.0):
        self.layout = layout
        self.top = top
        self.stack = stack
        self.dbu = layout.dbu
        self.conductors = stack["conductors"]
        self.cut_specs = stack["cuts"]
        self.cond_index = {c["name"]: i for i, c in enumerate(self.conductors)}
        self.bucket = max(1, int(round(bucket_um / self.dbu)))
        self.black_box = self._black_box_cells(black_box, keep)

        self.node_cond: list[int] = []
        self.node_poly: list = []
        self.node_traps: list = []
        self.node_terms: dict[int, list] = defaultdict(list)
        self.node_net: list[int] = []
        self.index = [_Index(self.bucket) for _ in self.conductors]
        self.cond_nodes: list[range] = []

        self.cut_spec: list[int] = []
        self.cut_poly: list = []
        self.cut_center: list[tuple[int, int]] = []
        self.cut_neq: list[int] = []
        self.cut_lower: list[int] = []
        self.cut_upper: list[int] = []

        # black-box instances: (cell name, ICplxTrans) and their pins: (instance, pin name, conductor, polygon, node)
        self.bb_instances: list[tuple[str, object]] = []
        self.pins: list[list] = []
        self.labels: list[tuple[str, int, int, int, int, int]] = []  # text, conductor, x, y, node, cell depth
        self.pads: list[tuple[int, object]] = []  # node, pad region (polygon under the passivation opening)

        bb_pins = self._read_black_boxes()
        self._read_conductors(bb_pins)
        self._read_cuts()
        self._read_labels()
        self._read_pads()
        self._mark_device_terminals()
        self.nets: list[Net] = []
        self._build_nets()

    # --- reading -------------------------------------------------------------------------------------------------

    def to_dbu(self, value_um: float) -> int:
        return int(round(value_um / self.dbu))

    def _black_box_cells(self, patterns, keep) -> set:
        cells = set()
        if not patterns:
            return cells
        for ci in self.top.called_cells():
            name = self.layout.cell(ci).name
            if any(fnmatch.fnmatchcase(name, p) for p in patterns) and \
                    not any(fnmatch.fnmatchcase(name, k) for k in keep):
                cells.add(ci)
        return cells

    def _layer_index(self, spec):
        if spec is None:
            return None
        return self.layout.find_layer(spec[0], spec[1])

    def _region(self, layers, cell=None):
        """The flat region of some layers below ``cell`` (default: the top cell), black boxes left out."""
        region = pya.Region()
        cell = cell or self.top
        for spec in layers:
            li = self._layer_index(spec)
            if li is None:
                continue
            it = pya.RecursiveShapeIterator(self.layout, cell, li)
            if self.black_box and cell is self.top:
                it.unselect_cells(list(self.black_box))
            region.insert(it)
        return region

    def _cell_pins(self, cell) -> list:
        """The pin shapes of a cell as (name, conductor, polygon) in cell coordinates."""
        pins = []
        for ci, cond in enumerate(self.conductors):
            pin_li = self._layer_index(cond.get("pin"))
            if pin_li is None:
                continue
            texts = defaultdict(list)  # bucket -> (text, point), a cell can hold thousands of pins and labels
            b = self.bucket
            for spec in (cond.get("label"), cond.get("pin")):
                li = self._layer_index(spec)
                if li is None:
                    continue
                it = pya.RecursiveShapeIterator(self.layout, cell, li)
                while not it.at_end():
                    shape = it.shape()
                    if shape.is_text():
                        text = shape.text.transformed(it.trans())
                        texts[(text.x // b, text.y // b)].append((text.string, pya.Point(text.x, text.y)))
                    it.next()
            it = pya.RecursiveShapeIterator(self.layout, cell, pin_li)
            while not it.at_end():
                shape = it.shape()
                if shape.is_box() or shape.is_polygon() or shape.is_path():
                    poly = shape.polygon.transformed(it.trans())
                    box = poly.bbox()
                    names = sorted({t for ix in range(box.left // b, box.right // b + 1)
                                    for iy in range(box.bottom // b, box.top // b + 1)
                                    for t, p in texts.get((ix, iy), ()) if poly.inside(p)})
                    pins.append((names[0] if names else "", ci, poly))
                it.next()
        if any(not name for name, _ci, _poly in pins):
            pins = self._name_by_connectivity(cell, pins)
        return pins

    def _name_by_connectivity(self, cell, pins: list) -> list:
        """Name unlabelled pin shapes after the labelled pins they connect to inside the cell.

        A LibreLane macro labels one of its supply stripes, the others are pins of the same net without a label.
        """
        sub = Extraction(self.layout, cell, self.stack, bucket_um=self.bucket * self.dbu)
        names_of_net = defaultdict(set)
        nets = []
        for name, ci, poly in pins:
            x, y = inner_point(poly)
            n = sub.index[ci].find(x, y)
            k = sub.node_net[n] if n >= 0 else -1
            nets.append(k)
            if name and k >= 0:
                names_of_net[k].add(name)
        for text, _ci, _x, _y, n, depth in sub.labels:
            if n >= 0 and depth == 0 and sub.node_net[n] >= 0:
                names_of_net[sub.node_net[n]].add(text)
        named = []
        for (name, ci, poly), k in zip(pins, nets):
            if not name and k >= 0 and len(names_of_net[k]) == 1:
                name = next(iter(names_of_net[k]))
            named.append((name, ci, poly))
        return named

    def _contains_black_box(self) -> dict:
        contains = {}
        for ci in self.top.called_cells():
            called = set(self.layout.cell(ci).called_cells())
            contains[ci] = bool(called & self.black_box)
        return contains

    def _read_black_boxes(self) -> list:
        """Walk the instances of the black-box cells, return their pin polygons per conductor (top coordinates)."""
        per_cond = [[] for _ in self.conductors]
        if not self.black_box:
            return per_cond
        cell_pins = {}
        contains = self._contains_black_box()
        todo = [(self.top.cell_index(), pya.ICplxTrans())]
        while todo:
            ci, trans = todo.pop()
            for inst in self.layout.cell(ci).each_inst():
                child = inst.cell_index
                if child not in self.black_box and not contains.get(child):
                    continue
                for itrans in inst.cell_inst.each_cplx_trans():
                    full = trans * itrans
                    if child in self.black_box:
                        if child not in cell_pins:
                            cell_pins[child] = self._cell_pins(self.layout.cell(child))
                        if not cell_pins[child]:
                            continue  # fill and logo cells: nothing of them stays
                        k = len(self.bb_instances)
                        self.bb_instances.append((self.layout.cell(child).name, full))
                        for name, cond, poly in cell_pins[child]:
                            tpoly = poly.transformed(full)
                            self.pins.append([k, name, cond, tpoly, -1])
                            per_cond[cond].append(tpoly)
                    else:
                        todo.append((child, full))
        return per_cond

    def _read_conductors(self, bb_pins: list) -> None:
        for ci, cond in enumerate(self.conductors):
            region = self._region(cond["layers"])
            if cond.get("minus"):
                region -= self._region(cond["minus"])
            body = None
            if cond.get("body"):
                body_layers = self._region(cond["body"])
                body = region & body_layers
                region -= body_layers
            for poly in bb_pins[ci]:
                region.insert(poly)
            region.merge()
            first = len(self.node_cond)
            for poly in region.each():
                n = len(self.node_cond)
                traps = poly.decompose_trapezoids(pya.Polygon.TD_htrapezoids)
                self.node_cond.append(ci)
                self.node_poly.append(poly)
                self.node_traps.append(traps)
                for trap in traps:
                    self.index[ci].add(n, trap)
            self.cond_nodes.append(range(first, len(self.node_cond)))
            if body is not None and not body.is_empty():
                self._mark_interacting(ci, region, body, "body")
        for pin in self.pins:
            x, y = inner_point(pin[3])
            pin[4] = self.index[pin[2]].find(x, y)
            if pin[4] >= 0:
                self.node_terms[pin[4]].append(("pin", f"{self.bb_instances[pin[0]][0]}/{pin[1]}"))

    def _mark_interacting(self, ci: int, region, other, name: str) -> None:
        for poly in region.interacting(other).each():
            x, y = inner_point(poly)
            n = self.index[ci].find(x, y)
            if n >= 0:
                self.node_terms[n].append(("device", name))

    def _mark_device_terminals(self) -> None:
        for ci, cond in enumerate(self.conductors):
            if cond.get("terminal") == "all":
                for n in self.cond_nodes[ci]:
                    self.node_terms[n].append(("device", cond["name"]))
            elif cond.get("terminal_with"):
                other = self._region(cond["terminal_with"])
                if other.is_empty():
                    continue
                region = pya.Region()
                for n in self.cond_nodes[ci]:
                    region.insert(self.node_poly[n])
                self._mark_interacting(ci, region, other, cond["name"])

    def _equivalent_cuts(self, spec: dict, poly) -> int:
        """Cuts a merged cut polygon stands for, the smaller of two counts.

        One count goes per cut pitch along each side of the bounding box (a contact bar counts by its length), the
        other by area in cut squares, so an L-shaped or offset double-drawn cut does not count as a full array.
        """
        size = spec.get("size")
        if not size:
            return 1
        pitch = size + spec["space"]
        box = poly.bbox()
        by_pitch = 1
        for length in (box.width() * self.dbu, box.height() * self.dbu):
            by_pitch *= 1 + max(0, int(math.floor((length - size) / pitch + 1e-6)))
        by_area = int(math.floor(poly.area() * self.dbu ** 2 / size ** 2 + 1e-6))
        return max(1, min(by_pitch, by_area))

    def _read_cuts(self) -> None:
        for k, spec in enumerate(self.cut_specs):
            region = self._region(spec["layers"])
            if spec.get("and_layers"):
                region &= self._region(spec["and_layers"])
            if spec.get("minus"):
                region -= self._region(spec["minus"])
            region.merge()
            lower = [self.cond_index[name] for name in spec["lower"] if name in self.cond_index]
            upper = self.cond_index.get(spec["upper"], -1)
            for poly in region.each():
                box = poly.bbox()
                cx, cy = box.center().x, box.center().y
                if not poly.inside(pya.Point(cx, cy)):
                    cx, cy = inner_point(poly)
                lo = -1
                for ci in lower:
                    lo = self.index[ci].find(cx, cy)
                    if lo >= 0:
                        break
                up = self.index[upper].find(cx, cy) if upper >= 0 else -1
                self.cut_spec.append(k)
                self.cut_poly.append(poly)
                self.cut_center.append((cx, cy))
                self.cut_neq.append(self._equivalent_cuts(spec, poly))
                self.cut_lower.append(lo)
                self.cut_upper.append(up)

    def _read_labels(self) -> None:
        """Labels of every cell read (black boxes left out) name the nets, only those of the top cell are terminals.

        A chip's labels can sit one level down (the delivery GDS wraps the chip cell with fill and logo), and a label
        inside a subcell marks that cell's pin, not a terminal of the flat net.
        """
        for ci, cond in enumerate(self.conductors):
            for spec in (cond.get("label"), cond.get("pin")):
                li = self._layer_index(spec)
                if li is None:
                    continue
                it = pya.RecursiveShapeIterator(self.layout, self.top, li)
                it.shape_flags = pya.Shapes.STexts
                if self.black_box:
                    it.unselect_cells(list(self.black_box))
                while not it.at_end():
                    text = it.shape().text.transformed(it.trans())
                    depth = len(it.path())
                    n = self.index[ci].find(text.x, text.y)
                    self.labels.append((text.string, ci, text.x, text.y, n, depth))
                    if n >= 0 and depth == 0:
                        self.node_terms[n].append(("label", text.string))
                    it.next()

    def _read_pads(self) -> None:
        pad = self.stack.get("pad")
        if not pad or pad["conductor"] not in self.cond_index:
            return
        ci = self.cond_index[pad["conductor"]]
        opening = self._region(pad["layers"])
        if opening.is_empty():
            return
        for n in self.cond_nodes[ci]:
            area = pya.Region(self.node_poly[n]) & opening
            if not area.is_empty():
                self.pads.append((n, area))
                self.node_terms[n].append(("pad", ""))

    # --- nets ----------------------------------------------------------------------------------------------------

    def _build_nets(self) -> None:
        parent = list(range(len(self.node_cond)))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for lo, up in zip(self.cut_lower, self.cut_upper):
            if lo >= 0 and up >= 0:
                ra, rb = find(lo), find(up)
                if ra != rb:
                    parent[ra] = rb
        net_of_root = {}
        self.node_net = [-1] * len(self.node_cond)
        for c, (lo, up) in enumerate(zip(self.cut_lower, self.cut_upper)):
            for n in (lo, up):
                if n >= 0:
                    net_of_root.setdefault(find(n), None)
        for n in self.node_terms:
            net_of_root.setdefault(find(n), None)
        for root in sorted(net_of_root, key=lambda r: r):
            net_of_root[root] = len(self.nets)
            self.nets.append(Net(len(self.nets)))
        for n in range(len(self.node_cond)):
            k = net_of_root.get(find(n))
            if k is not None:
                self.node_net[n] = k
                self.nets[k].nodes.append(n)
        for c, (lo, up) in enumerate(zip(self.cut_lower, self.cut_upper)):
            n = lo if lo >= 0 else up
            if n >= 0 and lo >= 0 and up >= 0:
                self.nets[self.node_net[n]].cuts.append(c)
        depth_of = defaultdict(dict)  # net -> label -> smallest cell depth it sits at
        for text, _ci, _x, _y, n, depth in self.labels:
            if n >= 0 and self.node_net[n] >= 0:
                k = self.node_net[n]
                if text not in depth_of[k]:
                    self.nets[k].labels.append(text)
                depth_of[k][text] = min(depth, depth_of[k].get(text, depth))
        for p, (n, _area) in enumerate(self.pads):
            self.nets[self.node_net[n]].pads.append(p)
        for p, pin in enumerate(self.pins):
            if pin[4] >= 0:
                self.nets[self.node_net[pin[4]]].pins.append(p)
        for net in self.nets:
            if net.labels:
                top = min(depth_of[net.index].values())
                net.name = ",".join(sorted(t for t, d in depth_of[net.index].items() if d == top))
            elif net.pins:
                pin = self.pins[net.pins[0]]
                net.name = f"{self.bb_instances[pin[0]][0]}/{pin[1] or '?'}"
            else:
                x, y = inner_point(self.node_poly[net.nodes[0]])
                net.name = f"net@{x * self.dbu:.3f},{y * self.dbu:.3f}"

    def dangling_cuts(self) -> list[int]:
        """Cuts that miss a conductor polygon on one side (or both)."""
        return [c for c in range(len(self.cut_spec)) if self.cut_lower[c] < 0 or self.cut_upper[c] < 0]

    def unattached_labels(self) -> list[tuple]:
        """Labels of the top cell that sit on no polygon of their conductor."""
        return [lab for lab in self.labels if lab[4] < 0 and lab[5] == 0]

    def owner(self, c: int) -> str:
        """The cell that draws cut ``c`` (the first one found under its center)."""
        spec = self.cut_specs[self.cut_spec[c]]
        cx, cy = self.cut_center[c]
        probe = pya.Box(cx - 1, cy - 1, cx + 1, cy + 1)
        for layer in spec["layers"]:
            li = self._layer_index(layer)
            if li is None:
                continue
            it = pya.RecursiveShapeIterator(self.layout, self.top, li, probe, True)
            if self.black_box:
                it.unselect_cells(list(self.black_box))
            if not it.at_end():
                return it.cell().name
        return self.top.name

    # --- graph questions -----------------------------------------------------------------------------------------

    def is_terminal(self, n: int) -> bool:
        return bool(self.node_terms.get(n))

    def opening_cuts(self, net: Net) -> list[int]:
        """The cuts of ``net`` whose removal splits it into two parts that both hold a terminal.

        Such a cut is a bridge of the graph. A merged cut that stands for several cuts (a contact bar) counts as
        parallel edges and is never a bridge. The pin shapes of one black-box instance that share a name are joined
        inside the black box, so they are joined here too.
        """
        local = {n: i for i, n in enumerate(net.nodes)}
        adj = [[] for _ in net.nodes]
        edge_cut = []
        for c in net.cuts:
            a, b = local[self.cut_lower[c]], local[self.cut_upper[c]]
            for _ in range(min(2, self.cut_neq[c])):
                e = len(edge_cut)
                edge_cut.append(c)
                adj[a].append((b, e))
                adj[b].append((a, e))
        same_pin = defaultdict(set)
        for p in net.pins:
            k, name, _ci, _poly, node = self.pins[p]
            if name:
                same_pin[(k, name)].add(local[node])
        for members in same_pin.values():
            members = sorted(members)
            for a, b in zip(members, members[1:]):
                for _ in range(2):  # two parallel edges, never a bridge
                    e = len(edge_cut)
                    edge_cut.append(-1)
                    adj[a].append((b, e))
                    adj[b].append((a, e))
        n_nodes = len(net.nodes)
        tin = [-1] * n_nodes
        low = [0] * n_nodes
        sub = [1 if self.is_terminal(n) else 0 for n in net.nodes]
        bridges = []
        timer = 0
        for root in range(n_nodes):
            if tin[root] >= 0:
                continue
            tin[root] = low[root] = timer
            timer += 1
            todo = [(root, -1, iter(adj[root]))]
            found = []
            while todo:
                v, pe, it = todo[-1]
                descended = False
                for w, e in it:
                    if e == pe:
                        continue
                    if tin[w] < 0:
                        tin[w] = low[w] = timer
                        timer += 1
                        todo.append((w, e, iter(adj[w])))
                        descended = True
                        break
                    low[v] = min(low[v], tin[w])
                if descended:
                    continue
                todo.pop()
                if todo:
                    u = todo[-1][0]
                    low[u] = min(low[u], low[v])
                    sub[u] += sub[v]
                    if low[v] > tin[u]:
                        found.append((pe, v))
            total = sub[root]
            for e, v in found:
                if 0 < sub[v] < total:
                    bridges.append(edge_cut[e])
        return bridges

    def has_room(self, c: int) -> bool | None:
        """Whether the landing of cut ``c`` holds a second cut, by the size, space and enclosure rules.

        The landing is the overlap of the lower and the upper polygon near the cut. Each polygon is shrunk by its
        enclosure (all sides, and the endcap on two opposite sides, tried both ways) plus half the cut size, which
        leaves the region where a cut center may sit. Two cuts fit when that region spans one cut pitch along x or
        along y. None if the cut layer has no rules in the stack. Not tested: a diagonal pair, the array spacing of
        large arrays, and rules to other layers (a contact's space to gate or diffusion).
        """
        spec = self.cut_specs[self.cut_spec[c]]
        if not spec.get("size") or spec.get("enc_lower") is None or spec.get("enc_upper") is None:
            return None
        size, pitch = spec["size"], spec["size"] + spec["space"]
        enc_lo, enc_up = spec["enc_lower"], spec["enc_upper"]
        half = self.to_dbu(2 * pitch + size + 2 * max(enc_lo + enc_up))
        cx, cy = self.cut_center[c]
        window = pya.Region(pya.Box(cx - half, cy - half, cx + half, cy + half))
        lower = pya.Region(self.node_poly[self.cut_lower[c]]) & window
        upper = pya.Region(self.node_poly[self.cut_upper[c]]) & window
        need = self.to_dbu(pitch)

        def shrunk(region, enc, endcap_on_x):
            ex, ey = (enc[1], enc[0]) if endcap_on_x else (enc[0], enc[1])
            # the explicit mode 2 selects the anisotropic sized(dx, dy, mode), sized(d, mode) would take dy as mode
            return region.sized(-self.to_dbu(ex + size / 2), -self.to_dbu(ey + size / 2), 2)

        for lo_x in (True, False):
            lo = shrunk(lower, enc_lo, lo_x)
            if lo.is_empty():
                continue
            for up_x in (True, False):
                centers = lo & shrunk(upper, enc_up, up_x)
                if centers.is_empty():
                    continue
                box = centers.bbox()
                if box.width() >= need or box.height() >= need:
                    return True
        return False


class Markers:
    """A KLayout report database (.lyrdb) for the marker browser."""

    def __init__(self, name: str, top_name: str, dbu: float):
        self.rdb = pya.ReportDatabase(name)
        self.rdb.top_cell_name = top_name
        self.cell = self.rdb.create_cell(top_name)
        self.dbu = dbu
        self.categories = {}

    def category(self, name: str, description: str = ""):
        if name not in self.categories:
            cat = self.rdb.create_category(name)
            cat.description = description
            self.categories[name] = cat
        return self.categories[name]

    def add(self, category: str, shape, text: str = "") -> None:
        """Add a marker: ``shape`` is a Box or Polygon in database units."""
        item = self.rdb.create_item(self.cell.rdb_id(), self.category(category).rdb_id())
        if isinstance(shape, pya.Box):
            item.add_value(pya.DBox(shape.left * self.dbu, shape.bottom * self.dbu,
                                    shape.right * self.dbu, shape.top * self.dbu))
        else:
            item.add_value(shape.to_dtype(self.dbu))
        if text:
            item.add_value(text)

    def save(self, path: str) -> None:
        self.rdb.save(path)
