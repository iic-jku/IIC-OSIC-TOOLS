#!/usr/bin/env python3
# ========================================================================
# DC current density of the wires and cuts of a layout against the PDK limits
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
# Usage: sak-current-density.py check [--json] [--max <n>] [-t <pdk>] [-c <cell>]
#                                     (-b <budget.yaml> | -v <view.yaml> -s <state>) [--pixel <um>]
#                                     [--max-nodes <n>] [--warn <ratio>] [-w <workdir>] <layout>
#        sak-current-density.py view -o <view.yaml> --gds <gds> --state <state> --source <text> [--cell <cell>]
#                                    [-t <pdk>] (--data <file> | --current <pin>=<mA>... |
#                                    --sta-power <report> --supply <pin>=<V> --ground <pin>)
#
# This script uses KLayout (https://www.klayout.de), NumPy, SciPy and PyYAML.
# ========================================================================

"""Check the time-averaged DC current of the wires and cuts against the PDK limits.

``check`` takes the currents from a budget (``-b``, a chip) or from the current
view of the layout itself (``-v`` and ``-s``, a macro) and judges each net in
three stages:

  1. Floor: a net whose current is below the weakest single element of the PDK
     (one cut or one wire of minimum width) passes without geometry. DC current
     flows from higher to lower potential through every element but a source,
     so it never circulates, and no wire or cut carries more than the current
     fed into its net. The floor is exact.
  2. Screen: that current against the narrowest section of every wire and
     against every single cut. A net that passes is proven.
  3. Solve: a static resistive solve on a pixel mesh of the drawn metal (pads
     or source labels at 0 V, loads where they enter). The current summed over
     each wire cross-section is held against the limit for its width, and the
     worst single cut of each cut array against the limit per cut. Contacts and
     the device layers (diffusion, poly) are not in the solve, the floor and the
     screen check the contacts.

A macro checked on its own knows the currents of its pins, not of its devices.
A net that reaches a diffusion or a resistor or inductor body can carry up to
the macro's whole supply current, any other net (gates, capacitor plates) the
current of its pins. Such nets get the floor and the screen, and a net the
screen cannot clear stays unresolved.

Budget (YAML, paths relative to the budget file, currents in mA into the load):

  black_box: [<cell glob>, ...]        cells left out, their pin shapes stay
  keep: [<cell glob>, ...]             cells read although a black_box glob matches
  views:                               macro current views, their cells become black boxes
    - {view: <view.yaml>, state: <state>}
  nets:
    <label>:
      sources: [<label>, ...]          default: every pad of the net
      loads:
        - {cells: [<glob>], exclude: [<glob>], pin: <pin or list>, current_ma: <mA>, source: <text>}
        - {label: <label>, current_ma: <mA>, source: <text>}

A ``cells`` load is spread evenly over the black-box instances, a ``label``
load enters at the label. A view's pin currents enter each instance of its cell
at the pin shapes of the pin, joined into one node (the macro inside is taken
as ideal). The pin shapes of a black box are named by the label inside them,
or by the labelled pin they connect to inside the cell.

``view`` writes a current view: per state the average current into each pin of
a cell (mA, into the cell positive), from a data file of ``<pin> <ampere>``
lines (as ngspice ``echo VDD $&ivdd > file`` writes them), from ``--current``
values, or from the total power of an OpenSTA ``report_power`` divided by the
supply voltage. The view records a digest of the cell's GDS (SHA-256 of its
records without the time stamps). ``check`` refuses a view whose GDS has changed
since, a macro layout that is not the one of its view, and a chip whose copy of
a macro differs from the macro's GDS.

Outputs of ``check`` in the work directory (``-w``, default: current directory):
``<cell>_current_density.rpt`` and ``<cell>_current_density.lyrdb``.

Exit codes: 0 no element above its limit (unresolved nets are warnings), 1 an
element above its limit, 2 input missing, unreadable, inconsistent or stale,
3 wrong usage (including a PDK without a metal stack).
"""

import bisect
import fnmatch
import gzip
import hashlib
import math
import os
import re
import sys
import time
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # noqa: E402
import sak_tech  # noqa: E402

TOOL = "sak-current-density"

try:
    import numpy as np
    import scipy.sparse as sp
    import scipy.sparse.csgraph as csgraph
    import scipy.sparse.linalg as spla
    import yaml
    import sak_netgraph  # noqa: E402
    from sak_netgraph import pya  # noqa: E402
except ImportError as _exc:
    sak_json.fail(TOOL, f"missing Python module: {_exc}", "--json" in sys.argv[1:])

TILE_UM = 20.0  # the report keeps the worst section per conductor, direction and tile of this size
DC_TERMINALS = {"Activ", "body"}  # device terminals that pass DC current (diffusion, resistor and inductor bodies)


class BudgetError(Exception):
    """A budget or view is missing, malformed, inconsistent with the layout, or stale."""


# --- limits ---------------------------------------------------------------------------------------------------------

def wire_limit(limit: dict, width_um):
    """The current limit (mA) of a wire section of the given width (scalar or array)."""
    width = np.asarray(width_um, dtype=float)
    value = limit["ma_per_um"] * width
    if limit.get("flat_ma") is not None:
        value = np.where(width <= limit["flat_um"], limit["flat_ma"], value)
    return value


def floor_ma(stack: dict) -> tuple[float, str]:
    """The current the weakest single element of the PDK carries, with a description."""
    best = (math.inf, "")
    for cut in stack["cuts"]:
        if cut.get("imax"):
            best = min(best, (cut["imax"], f"one {cut['name']}"))
    for cond in stack["conductors"]:
        if cond.get("limit"):
            value = float(wire_limit(cond["limit"], cond["min_width"]))
            best = min(best, (value, f"{cond['name']} of {cond['min_width']} um"))
    return best


# --- budget and views -----------------------------------------------------------------------------------------------

BUDGET_KEYS = {"black_box", "keep", "views", "nets"}
NET_KEYS = {"sources", "loads"}
LOAD_KEYS = {"cells", "exclude", "pin", "label", "current_ma", "source"}


def check_keys(where: str, mapping, allowed: set) -> None:
    """Refuse a key a budget does not know (a typo would leave a load out unnoticed), keys starting with _ are free."""
    if not isinstance(mapping, dict):
        raise BudgetError(f"{where} is not a mapping")
    unknown = sorted(str(k) for k in mapping if str(k) not in allowed and not str(k).startswith("_"))
    if unknown:
        raise BudgetError(f"{where}: unknown key {', '.join(unknown)} (known: {', '.join(sorted(allowed))})")


def number(value, where: str) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError):
        raise BudgetError(f"{where}: {value!r} is not a number") from None
    if not math.isfinite(result):
        raise BudgetError(f"{where}: {value!r} is not a finite number")
    return result


def names(value, where: str) -> list[str]:
    """A glob or name, or a list of them, as a list of strings."""
    if value is None:
        return []
    if isinstance(value, (str, int, float)):
        return [str(value)]
    if isinstance(value, list):
        return [str(v) for v in value]
    raise BudgetError(f"{where}: expected a name or a list of names, got {value!r}")


def read_yaml(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
    except OSError as exc:
        raise BudgetError(f"cannot read {path}: {exc.strerror}") from exc
    except yaml.YAMLError as exc:
        raise BudgetError(f"{path} is not valid YAML: {exc}") from exc
    if not isinstance(data, dict):
        raise BudgetError(f"{path} does not hold a mapping")
    return data


def gds_digest(path: str) -> str:
    """SHA-256 of the records of a GDS file (gzipped or not) without the time stamps of BGNLIB and BGNSTR.

    A layout written again with the same content keeps its digest, although every write stamps the time. A file
    that is no GDS stream is hashed as a whole.
    """
    try:
        with (gzip.open if path.endswith(".gz") else open)(path, "rb") as fh:
            data = fh.read()
    except (OSError, EOFError) as exc:
        raise BudgetError(f"cannot read {path}: {exc}") from exc
    digest = hashlib.sha256()
    pos = 0
    while pos + 4 <= len(data):
        length, rtype = int.from_bytes(data[pos:pos + 2], "big"), data[pos + 2]
        if length < 4 or pos + length > len(data) or (pos == 0 and rtype != 0x00):
            return hashlib.sha256(data).hexdigest()  # no HEADER record first, or a broken record
        # BGNLIB (0x01) and BGNSTR (0x05) carry only the modification and access times
        digest.update(data[pos + 2:pos + 4] if rtype in (0x01, 0x05) else data[pos:pos + length])
        pos += length
        if rtype == 0x04:  # ENDLIB, padding may follow
            return digest.hexdigest()
    return hashlib.sha256(data).hexdigest()


def stack_layers(stack: dict) -> set:
    """The layers that make up the conductors, device bodies and cuts of a stack (not pins, labels or markers)."""
    layers = set()
    for item in stack["conductors"] + stack["cuts"]:
        for key in ("layers", "minus", "body", "and_layers", "terminal_with"):
            layers.update(tuple(spec) for spec in item.get(key) or [])
    return layers


def flat_digest(layout, cell, layers: set) -> str:
    """SHA-256 of the merged polygons on the given layers of a cell and everything below it, whatever the cell names."""
    digest = hashlib.sha256()
    infos = sorted((layout.get_info(li).layer, layout.get_info(li).datatype, li) for li in layout.layer_indexes()
                   if (layout.get_info(li).layer, layout.get_info(li).datatype) in layers)
    for layer, datatype, li in infos:
        region = pya.Region(pya.RecursiveShapeIterator(layout, cell, li))
        if region.is_empty():
            continue
        digest.update(f"{layer}/{datatype}\n".encode())
        for text in sorted(str(p.to_dtype(layout.dbu)) for p in region.merged().each()):
            digest.update(text.encode() + b"\n")
    return digest.hexdigest()


def read_view(path: str, state: str) -> dict:
    """A current view and one of its states, after checking that its GDS is unchanged."""
    view = read_yaml(path)
    for key in ("cell", "gds", "gds_digest", "states"):
        if key not in view:
            raise BudgetError(f"{path} has no '{key}', write it with '{TOOL}.py view'")
    states = view["states"] or {}
    if not isinstance(states, dict) or not all(isinstance(k, str) for k in states):
        raise BudgetError(f"{path}: the state names must be text, write the view again")
    if state not in states:
        raise BudgetError(f"{path} has no state '{state}' (states: {', '.join(states)})")
    gds = os.path.normpath(os.path.join(os.path.dirname(path), str(view["gds"])))
    if gds_digest(gds) != view["gds_digest"]:
        raise BudgetError(f"{path} is stale: {gds} changed since the view was written, write the view again")
    entry = states[state]
    if not isinstance(entry, dict) or not isinstance(entry.get("pins_ma") or {}, dict):
        raise BudgetError(f"{path}: state {state} needs a mapping with pins_ma")
    pins = {str(k): number(v, f"{path}, state {state}, pin {k}") for k, v in (entry.get("pins_ma") or {}).items()}
    return {"path": path, "cell": str(view["cell"]), "state": state, "pins": pins, "gds": gds,
            "digest": view["gds_digest"],
            "source": f"{os.path.basename(path)} state {state}: {entry.get('source', 'no source given')}"}


# --- the nets to judge ----------------------------------------------------------------------------------------------

class Injection:
    """Current entering a net (mA, into the net positive) at a terminal.

    kind ``ideal``: one node joining the pieces under ``polys``, ``spread``: over the pieces under ``polys`` by
    area, ``point``: at the piece under ``point``. ``polys`` holds (node, polygon) pairs.
    """

    def __init__(self, kind, ma, node, what, source, polys=None, point=None):
        self.kind, self.ma, self.node, self.what, self.source = kind, ma, node, what, source
        self.polys = polys or []
        self.point = point


class Case:
    """One net to judge, with its loads and sources, or with a bound on its current (a macro on its own)."""

    def __init__(self, net):
        self.net = net
        self.injections: list[Injection] = []
        self.sources: list[tuple] = []  # (node, region or None, point or None, name)
        self.placed = True
        self.bound = None
        self.source_list: list[str] = []
        self.status = ""
        self.stage = ""
        self.rows: list[dict] = []
        self.notes: list[str] = []
        self.ir_mv: dict[str, float] = {}

    @property
    def total_ma(self) -> float:
        if self.bound is not None:
            return self.bound
        pos = sum(i.ma for i in self.injections if i.ma > 0)
        neg = -sum(i.ma for i in self.injections if i.ma < 0)
        return max(pos, neg)

    def source_texts(self) -> list[str]:
        seen = list(self.source_list)
        for inj in self.injections:
            if inj.source not in seen:
                seen.append(inj.source)
        return seen


def nets_by_label(ext) -> dict:
    found = defaultdict(list)
    for net in ext.nets:
        for name in set(net.labels):
            found[name].append(net)
    return found


def instance_pins(ext) -> dict:
    """{instance: {pin name: [pin index]}}"""
    pins = defaultdict(lambda: defaultdict(list))
    for p, pin in enumerate(ext.pins):
        pins[pin[0]][pin[1]].append(p)
    return pins


def default_sources(ext, case) -> None:
    for p in case.net.pads:
        node, area = ext.pads[p]
        labels = sorted({lab[0] for lab in ext.labels if lab[4] == node})
        case.sources.append((node, area, None, ",".join(labels) or "pad"))


def named_sources(ext, case, wanted: list) -> None:
    pads = {ext.pads[p][0]: ext.pads[p][1] for p in case.net.pads}
    for text, _ci, x, y, node, _depth in ext.labels:
        if text in wanted and node >= 0 and ext.node_net[node] == case.net.index:
            if node in pads:
                case.sources.append((node, pads[node], None, text))
            else:
                case.sources.append((node, None, (x, y), text))


def check_views_against_chip(ext, views: list) -> list[str]:
    """Refuse a chip whose copy of a macro differs from the GDS the macro's view was written for.

    The copies are compared on the conductors, device bodies and cuts only: the chip reads a black box by its pin
    shapes, and its currents follow from its devices and wiring, not from its markers.
    """
    warnings = []
    layers = stack_layers(ext.stack)
    for view in views:
        cell = ext.layout.cell(view["cell"])
        if cell is None:
            warnings.append(f"view {view['path']}: no cell {view['cell']} in the layout")
            continue
        macro_layout = sak_netgraph.read_layout(view["gds"])
        macro = sak_netgraph.pick_top(macro_layout, view["cell"], view["gds"])
        if flat_digest(ext.layout, cell, layers) != flat_digest(macro_layout, macro, layers):
            raise BudgetError(f"the layout holds another version of {view['cell']} than {view['gds']}, build the "
                              f"chip with the macro again or write the view for the macro the chip holds")
    return warnings


def build_budget_cases(ext, budget: dict, views: list) -> tuple[list, list, list]:
    """Cases from a budget: the nets named in it and the nets the views' pins reach. Also the pad nets left out."""
    cases = {}
    warnings = []
    by_label = nets_by_label(ext)
    inst_pins = instance_pins(ext)

    def case_of(net):
        if net.index not in cases:
            cases[net.index] = Case(net)
        return cases[net.index]

    for view in views:
        instances = [k for k, (name, _t) in enumerate(ext.bb_instances) if name == view["cell"]]
        if not instances:
            warnings.append(f"view {view['path']}: no instance of {view['cell']} in the layout")
        for k in instances:
            for pin, ma in view["pins"].items():
                indexes = [p for p in inst_pins[k].get(pin, []) if ext.pins[p][4] >= 0]
                if not indexes:
                    raise BudgetError(f"view {view['path']}: pin {pin} not found on {view['cell']} (pin shapes "
                                      f"named by a label inside them or by the labelled pin they connect to)")
                by_net = defaultdict(list)
                for p in indexes:
                    by_net[ext.node_net[ext.pins[p][4]]].append(p)
                if len(by_net) > 1:
                    # joined inside the macro but not by the chip metal: a part without a pad is fed by the macro
                    # itself and carries no chip current, every part with a pad may take the whole current
                    fed = {k: g for k, g in by_net.items() if ext.nets[k].pads}
                    if fed:
                        by_net = fed
                    if len(by_net) > 1:
                        warnings.append(f"view {view['path']}: the shapes of pin {pin} of {view['cell']} land on "
                                        f"{len(by_net)} nets with pads that the chip metal does not join, each "
                                        f"gets the whole current")
                for k_net, group in by_net.items():
                    case_of(ext.nets[k_net]).injections.append(Injection(
                        "ideal", -ma, ext.pins[group[0]][4], f"{view['cell']}/{pin}", view["source"],
                        polys=[(ext.pins[p][4], ext.pins[p][3]) for p in group]))

    nets_spec = budget.get("nets") or {}
    check_keys("budget nets", nets_spec, set(map(str, nets_spec)))
    for name, spec in nets_spec.items():
        nets = by_label.get(str(name))
        if not nets:
            raise BudgetError(f"budget net {name}: no net carries this label")
        if len(nets) > 1:
            warnings.append(f"budget net {name}: the label sits on {len(nets)} nets that metal does not join, "
                            f"each is checked on its own")
        spec = spec or {}
        check_keys(f"budget net {name}", spec, NET_KEYS)
        here = [case_of(net) for net in nets]
        if spec.get("sources"):
            wanted = names(spec["sources"], f"budget net {name}, sources")
            for case in here:
                named_sources(ext, case, wanted)
            if not any(case.sources for case in here):
                raise BudgetError(f"budget net {name}: none of the sources {wanted} is a label on it")
        loads = spec.get("loads") or []
        if not isinstance(loads, list):
            raise BudgetError(f"budget net {name}: loads must be a list")
        for load in loads:
            add_budget_load(ext, here, load, name, inst_pins)

    for case in cases.values():
        if not case.sources:
            default_sources(ext, case)
        if not case.injections:
            warnings.append(f"net {case.net.name}: the budget names it but gives it no load")
    budgeted = set(cases)
    left_out = sorted({ext.nets[ext.node_net[node]].name for node, _area in ext.pads
                       if ext.node_net[node] not in budgeted})
    return list(cases.values()), left_out, warnings


def add_budget_load(ext, cases: list, load: dict, net_name, inst_pins) -> None:
    where = f"budget net {net_name}, a load"
    check_keys(where, load, LOAD_KEYS)
    if "current_ma" not in load:
        raise BudgetError(f"{where} has no current_ma")
    ma = number(load["current_ma"], f"{where}, current_ma")
    source = str(load.get("source", "no source given"))
    by_index = {case.net.index: case for case in cases}
    if "label" in load:
        hits = [lab for lab in ext.labels if lab[0] == str(load["label"]) and lab[4] >= 0
                and ext.node_net[lab[4]] in by_index]
        if not hits:
            raise BudgetError(f"{where}: label {load['label']} is not on this net")
        _t, _ci, x, y, node, _depth = hits[0]
        by_index[ext.node_net[node]].injections.append(
            Injection("point", -ma, node, f"label {load['label']}", source, point=(x, y)))
        return
    patterns = names(load.get("cells"), f"{where}, cells")
    excludes = names(load.get("exclude"), f"{where}, exclude")
    pins = names(load.get("pin"), f"{where}, pin")
    if not patterns or not pins:
        raise BudgetError(f"{where} needs 'label', or 'cells' and 'pin'")
    members = []
    for k, (cell, _trans) in enumerate(ext.bb_instances):
        if not any(fnmatch.fnmatchcase(cell, p) for p in patterns) or \
                any(fnmatch.fnmatchcase(cell, e) for e in excludes):
            continue
        by_net = defaultdict(list)
        for pin in pins:
            for p in inst_pins[k].get(pin, []):
                node = ext.pins[p][4]
                if node >= 0 and ext.node_net[node] in by_index:
                    by_net[ext.node_net[node]].append(p)
        members += [(cell, group) for group in by_net.values()]
    if not members:
        raise BudgetError(f"{where}: no black-box instance of {patterns} has pin {'/'.join(pins)} on this net")
    share = ma / len(members)
    for cell, group in members:
        node = ext.pins[group[0]][4]
        by_index[ext.node_net[node]].injections.append(Injection(
            "spread", -share, node, f"{cell}/{'+'.join(pins)}", source,
            polys=[(ext.pins[p][4], ext.pins[p][3]) for p in group]))


def build_view_cases(ext, view: dict) -> list:
    """Cases of a macro checked on its own, each net with a bound on its current."""
    into = sum(v for v in view["pins"].values() if v > 0)
    out = -sum(v for v in view["pins"].values() if v < 0)
    total = max(into, out)
    pin_ma = defaultdict(float)
    by_label = nets_by_label(ext)
    for pin, ma in view["pins"].items():
        nets = by_label.get(pin)
        if not nets:
            raise BudgetError(f"view {view['path']}: no net carries the pin label {pin}")
        for net in nets:
            pin_ma[net.index] += abs(ma)
    cases = []
    for net in ext.nets:
        terms = {t for n in net.nodes for t in ext.node_terms.get(n, ())}
        dc = any(kind == "device" and name in DC_TERMINALS for kind, name in terms)
        if not dc and net.index not in pin_ma:
            continue  # gates and capacitor plates only, without a pin: no DC current
        case = Case(net)
        case.placed = False
        case.bound = total if dc else pin_ma[net.index]
        case.source_list = ["the macro's whole current (a DC path to its devices)" if dc else "its pins' current"]
        cases.append(case)
    return cases


# --- stage 2: screen ------------------------------------------------------------------------------------------------

def cut_arrays(ext, cuts: list) -> list[list[int]]:
    """Group cuts of one cut layer between the same two polygons into arrays of neighbors within two pitches."""
    groups = defaultdict(list)
    for c in cuts:
        groups[(ext.cut_spec[c], ext.cut_lower[c], ext.cut_upper[c])].append(c)
    arrays = []
    for (k, _lo, _up), members in groups.items():
        spec = ext.cut_specs[k]
        reach = ext.to_dbu(2 * (spec["size"] + spec["space"]) if spec.get("size") else 1.0)
        parent = {c: c for c in members}

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        buckets = defaultdict(list)
        for c in members:
            x, y = ext.cut_center[c]
            buckets[(x // reach, y // reach)].append(c)
        for (bx, by), here in buckets.items():
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for d in buckets.get((bx + dx, by + dy), ()):
                        for c in here:
                            if c < d:
                                x1, y1 = ext.cut_center[c]
                                x2, y2 = ext.cut_center[d]
                                if abs(x1 - x2) <= reach and abs(y1 - y2) <= reach:
                                    parent[find(c)] = find(d)
        clusters = defaultdict(list)
        for c in members:
            clusters[find(c)].append(c)
        arrays.extend(clusters.values())
    return arrays


def screen(ext, case, current_ma: float) -> list[dict]:
    """The elements of the net that cannot carry the whole net current (empty: the net passes)."""
    failures = []
    by_cond = defaultdict(list)
    for n in case.net.nodes:
        by_cond[ext.node_cond[n]].append(n)
    for ci, nodes in by_cond.items():
        cond = ext.conductors[ci]
        limit = cond.get("limit")
        if not limit:
            continue
        if limit.get("flat_ma") is not None and current_ma <= limit["flat_ma"]:
            continue
        need = current_ma / limit["ma_per_um"]
        region = pya.Region()
        for n in nodes:
            region.insert(ext.node_poly[n])
        narrow = region.width_check(int(math.ceil(need / ext.dbu)))
        if not narrow.is_empty():
            failures.append({"element": f"{cond['name']} narrower than {need:.3f} um", "box": narrow.bbox()})
    # every single cut: the outer cuts of an array carry more than the mean, so an array's summed capacity is no bound
    for c in case.net.cuts:
        spec = ext.cut_specs[ext.cut_spec[c]]
        if spec.get("imax") and ext.cut_neq[c] * spec["imax"] < current_ma:
            failures.append({"element": f"one {spec['name']}", "box": ext.cut_poly[c].bbox()})
    return failures


# --- stage 3: resistive solve ---------------------------------------------------------------------------------------

def trap_slices(trap, pixel: int) -> list:
    """The rows of a trapezoid (its horizontal edges on top and bottom) on the pixel grid.

    Each slice is (row, y1, y2, bottom left x, bottom right x, top left x, top right x, slanted), so a slanted side
    keeps its exact extent on the row boundary, where the slice meets the next one.
    """
    pts = [(p.x, p.y) for p in trap.each_point()]
    yb = min(p[1] for p in pts)
    yt = max(p[1] for p in pts)
    if yt <= yb:
        return []
    bottom = sorted(p[0] for p in pts if p[1] == yb)
    top = sorted(p[0] for p in pts if p[1] == yt)
    xbl, xbr, xtl, xtr = bottom[0], bottom[-1], top[0], top[-1]
    slanted = xbl != xtl or xbr != xtr
    out = []
    for row in range(yb // pixel, -(-yt // pixel)):
        y1 = max(yb, row * pixel)
        y2 = min(yt, (row + 1) * pixel)
        if y2 <= y1:
            continue
        t1 = (y1 - yb) / (yt - yb)
        t2 = (y2 - yb) / (yt - yb)
        out.append((row, y1, y2, xbl + (xtl - xbl) * t1, xbr + (xtr - xbr) * t1,
                    xbl + (xtl - xbl) * t2, xbr + (xtr - xbr) * t2, slanted))
    return out


def edge_length(xb, y1, y2, xb1, xb2, xt1, xt2):
    """Length of a slice on the vertical line x = xb (arrays).

    The slice's left side runs from xb1 (bottom) to xt1 (top), its right side from xb2 to xt2. With t from 0 at the
    bottom to 1 at the top, the line is inside where the left side is at most xb and the right side at least xb.
    """
    xb = np.asarray(xb, dtype=float)
    lo = np.zeros(xb.shape)
    hi = np.ones(xb.shape)
    dl = np.asarray(xt1 - xb1, dtype=float)
    dr = np.asarray(xt2 - xb2, dtype=float)
    tl = (xb - xb1) / np.where(dl != 0, dl, 1.0)
    tr = (xb - xb2) / np.where(dr != 0, dr, 1.0)
    hi = np.where(dl > 0, np.minimum(hi, tl), hi)  # left side moves right: inside below tl
    lo = np.where(dl < 0, np.maximum(lo, tl), lo)  # left side moves left: inside above tl
    hi = np.where((dl == 0) & (xb1 > xb), -1.0, hi)
    lo = np.where(dr > 0, np.maximum(lo, tr), lo)  # right side moves right: inside above tr
    hi = np.where(dr < 0, np.minimum(hi, tr), hi)  # right side moves left: inside below tr
    hi = np.where((dr == 0) & (xb2 < xb), -1.0, hi)
    return np.clip(hi - lo, 0.0, None) * (y2 - y1)


class Mesh:
    """The metal of one net as convex pieces per pixel, solved for its loads.

    Each trapezoid of a merged polygon is cut into the rows of the pixel grid (slices) and each slice into the
    columns (pieces), and every piece is a node. Two pieces conduct across the pixel edge they share, with the length
    of metal on that edge, so two parts of one polygon closer than a pixel stay apart unless their metal touches.
    """

    def __init__(self, ext, case, pixel_um: float, max_nodes: int):
        self.ext = ext
        self.case = case
        self.nodes = [n for n in case.net.nodes if ext.conductors[ext.node_cond[n]].get("rs")]
        if not self.nodes:
            raise BudgetError(f"net {case.net.name}: no metal with a sheet resistance to solve")
        conds = sorted({ext.node_cond[n] for n in self.nodes})
        start = pixel_um
        for _ in range(6):
            self.pix = {ci: ext.to_dbu(max(pixel_um, ext.conductors[ci]["min_width"] / 2)) for ci in conds}
            count = self._count()
            if count <= max_nodes:
                break
            pixel_um *= math.sqrt(count / max_nodes) * 1.1
        else:
            raise BudgetError(f"net {case.net.name}: more than {max_nodes} nodes even at {pixel_um:.2f} um pixels")
        if pixel_um > start:
            case.notes.append(f"pixel raised from {start} to {pixel_um:.3f} um to stay below {max_nodes} nodes")
        self.pixel_um = pixel_um
        self._build()

    def _count(self) -> int:
        count = 0
        for n in self.nodes:
            p = self.pix[self.ext.node_cond[n]]
            for trap in self.ext.node_traps[n]:
                for s in trap_slices(trap, p):
                    count += max(0, math.ceil(max(s[4], s[6]) / p) - math.floor(min(s[3], s[5]) / p))
        return count

    def _build(self) -> None:
        ext = self.ext
        cols = defaultdict(list)
        self.by_row = defaultdict(list)  # (node, row) -> slices
        first = 0
        for n in self.nodes:
            p = self.pix[ext.node_cond[n]]
            for trap in ext.node_traps[n]:
                for row, y1, y2, xb1, xb2, xt1, xt2, slanted in trap_slices(trap, p):
                    c0 = math.floor(min(xb1, xt1) / p)
                    c1 = math.ceil(max(xb2, xt2) / p)
                    if c1 <= c0:
                        continue
                    self.by_row[(n, row)].append(len(cols["node"]))
                    for key, value in (("node", n), ("row", row), ("y1", y1), ("y2", y2), ("xb1", xb1),
                                       ("xb2", xb2), ("xt1", xt1), ("xt2", xt2), ("slanted", slanted),
                                       ("c0", c0), ("c1", c1), ("first", first), ("pix", p)):
                        cols[key].append(value)
                    first += c1 - c0
        self.count = first
        self.s = {k: np.array(v) for k, v in cols.items()}

    def piece(self, s: int, col: int) -> int:
        return int(self.s["first"][s] + col - self.s["c0"][s])

    def piece_at(self, node: int, x: int, y: int) -> int:
        """The piece of a node under a point, -1 if none."""
        s_ = self.s
        p = self.pix[self.ext.node_cond[node]]
        for row in (y // p, y // p - 1):
            for s in self.by_row.get((node, row), ()):
                y1, y2 = s_["y1"][s], s_["y2"][s]
                if not y1 <= y <= y2:
                    continue
                t = (y - y1) / (y2 - y1)
                xl = s_["xb1"][s] + (s_["xt1"][s] - s_["xb1"][s]) * t
                xr = s_["xb2"][s] + (s_["xt2"][s] - s_["xb2"][s]) * t
                if xl <= x <= xr:
                    col = min(max(x // p, s_["c0"][s]), s_["c1"][s] - 1)
                    return self.piece(s, col)
        return -1

    def pieces_under(self, node: int, poly) -> tuple:
        """Pieces of a node covered by a polygon or region, with the covered area as weight."""
        s_ = self.s
        p = self.pix[self.ext.node_cond[node]]
        polys = list(poly.each()) if isinstance(poly, pya.Region) else [poly]
        weights = defaultdict(float)
        for q in polys:
            for trap in q.decompose_trapezoids(pya.Polygon.TD_htrapezoids):
                for row, y1, y2, xb1, xb2, xt1, xt2, _sl in trap_slices(trap, p):
                    for s in self.by_row.get((node, row), ()):
                        lo, hi = max(y1, s_["y1"][s]), min(y2, s_["y2"][s])
                        if hi <= lo:
                            continue
                        ym = (lo + hi) / 2
                        tq = (ym - y1) / (y2 - y1)
                        ts = (ym - s_["y1"][s]) / (s_["y2"][s] - s_["y1"][s])
                        ox1 = max(xb1 + (xt1 - xb1) * tq, s_["xb1"][s] + (s_["xt1"][s] - s_["xb1"][s]) * ts)
                        ox2 = min(xb2 + (xt2 - xb2) * tq, s_["xb2"][s] + (s_["xt2"][s] - s_["xb2"][s]) * ts)
                        if ox2 <= ox1:
                            continue
                        for col in range(max(math.floor(ox1 / p), s_["c0"][s]), min(math.ceil(ox2 / p), s_["c1"][s])):
                            w = (min(ox2, (col + 1) * p) - max(ox1, col * p)) * (hi - lo)
                            if w > 0:
                                weights[self.piece(s, col)] += w
        idx = np.fromiter(weights.keys(), dtype=np.int64, count=len(weights))
        return idx, np.fromiter(weights.values(), dtype=float, count=len(weights))

    def _links(self):
        """Wire links: (a, b, g) arrays, the horizontal links with their slice, column and edge length, the vertical
        links with their pair, column and edge length, the joins of touching pieces, and the section unions."""
        ext, s_ = self.ext, self.s
        rs = np.array([ext.conductors[ext.node_cond[n]]["rs"] for n in s_["node"]])
        # horizontal: across the column boundaries inside each slice
        ncol = s_["c1"] - s_["c0"]
        hs = np.repeat(np.arange(len(ncol)), np.maximum(ncol - 1, 0))
        offs = np.arange(len(hs)) - np.repeat(np.cumsum(np.maximum(ncol - 1, 0)) - np.maximum(ncol - 1, 0),
                                               np.maximum(ncol - 1, 0))
        hcol = s_["c0"][hs] + offs
        xb = (hcol + 1) * s_["pix"][hs]
        hlen = edge_length(xb, s_["y1"][hs], s_["y2"][hs], s_["xb1"][hs], s_["xb2"][hs], s_["xt1"][hs],
                           s_["xt2"][hs])
        keep = hlen > 0
        hs, hcol, hlen = list(hs[keep]), list(hcol[keep]), list(hlen[keep])
        ha = list(s_["first"][hs] + np.array(hcol, dtype=np.int64) - s_["c0"][hs]) if hs else []
        hb = [x + 1 for x in ha]
        hid = {(int(s), int(c)): i for i, (s, c) in enumerate(zip(hs, hcol))}

        va, vb, vg, vpair, vcol, vlen = [], [], [], [], [], []
        pairs = []  # (slice below, slice above, overlap from, overlap to, boundary y)
        join_a, join_b, unions = [], [], []

        def x_at(s, side, y):
            """x of the left (0) or right (1) side of a slice at height y."""
            y1, y2 = s_["y1"][s], s_["y2"][s]
            t = (y - y1) / (y2 - y1)
            if side == 0:
                return s_["xb1"][s] + (s_["xt1"][s] - s_["xb1"][s]) * t
            return s_["xb2"][s] + (s_["xt2"][s] - s_["xb2"][s]) * t

        # slices of one row that touch side by side (the decomposition also splits at vertical and slanted edges)
        for (n, row), members in self.by_row.items():
            if len(members) < 2:
                continue
            p = self.pix[ext.node_cond[n]]
            lefts = sorted((min(s_["xb1"][s], s_["xt1"][s]), s) for s in members)
            keys = [k for k, _s in lefts]
            for sa in members:
                lo_x = min(s_["xb2"][sa], s_["xt2"][sa]) - 1
                hi_x = max(s_["xb2"][sa], s_["xt2"][sa]) + 1
                j = bisect.bisect_left(keys, lo_x)
                while j < len(lefts) and lefts[j][0] <= hi_x:
                    sb = lefts[j][1]
                    j += 1
                    if sb == sa:
                        continue
                    ylo, yhi = max(s_["y1"][sa], s_["y1"][sb]), min(s_["y2"][sa], s_["y2"][sb])
                    if yhi <= ylo:
                        continue
                    xa = (x_at(sa, 1, ylo), x_at(sa, 1, yhi))
                    xs = (x_at(sb, 0, ylo), x_at(sb, 0, yhi))
                    if abs(xa[0] - xs[0]) > 1 or abs(xa[1] - xs[1]) > 1:
                        continue
                    ex1, ex2 = min(xa), max(xa)
                    if ex2 - ex1 <= 1 and round(ex1) % p == 0:
                        # on a pixel line: a link across it, which is also a section of that line
                        col = round(ex1) // p - 1
                        hid[(int(sa), col)] = hid[(int(sb), col)] = len(ha)
                        ha.append(self.piece(sa, col))
                        hb.append(self.piece(sb, col + 1))
                        hs.append(sa)
                        hcol.append(col)
                        hlen.append(float(yhi - ylo))
                    else:
                        for col in range(math.floor(ex1 / p), math.floor(ex2 / p) + 1):
                            if s_["c0"][sa] <= col < s_["c1"][sa] and s_["c0"][sb] <= col < s_["c1"][sb]:
                                join_a.append(self.piece(sa, col))
                                join_b.append(self.piece(sb, col))
        hs = np.array(hs, dtype=np.int64)
        hcol = np.array(hcol, dtype=np.int64)
        hlen = np.array(hlen, dtype=float)
        ha = np.array(ha, dtype=np.int64)
        hb = np.array(hb, dtype=np.int64)
        hg = hlen / s_["pix"][hs] / rs[hs] if len(hs) else np.array([])

        def connect(sa, sb, o1, o2, y, same_pixel):
            p = int(s_["pix"][sa])
            for col in range(math.floor(o1 / p), math.ceil(o2 / p)):
                length = min(o2, (col + 1) * p) - max(o1, col * p)
                if length <= 0:
                    continue
                a, b = self.piece(sa, col), self.piece(sb, col)
                if same_pixel:
                    join_a.append(a)
                    join_b.append(b)
                else:
                    va.append(a)
                    vb.append(b)
                    vg.append(length / p / rs[sa])
                    vpair.append(len(pairs))
                    vcol.append(col)
                    vlen.append(length)
            if not same_pixel:
                pairs.append((sa, sb, o1, o2, y))
            # a vertical cut line that passes from one slice into the other keeps one section
            for col in range(math.floor(o1 / p) - 1, math.ceil(o2 / p) + 1):
                xbound = (col + 1) * p
                if o1 <= xbound <= o2 and (sa, col) in hid and (sb, col) in hid:
                    unions.append((hid[(sa, col)], hid[(sb, col)]))

        def sweep(below, above, y, same_pixel):
            below = sorted(below, key=lambda s: s_["xt1"][s])
            above = sorted(above, key=lambda s: s_["xb1"][s])
            j0 = 0
            for sa in below:
                a1, a2 = s_["xt1"][sa], s_["xt2"][sa]
                while j0 < len(above) and s_["xb2"][above[j0]] <= a1:
                    j0 += 1
                for sb in above[j0:]:
                    if s_["xb1"][sb] >= a2:
                        break
                    o1, o2 = max(a1, s_["xb1"][sb]), min(a2, s_["xb2"][sb])
                    if o2 > o1:
                        connect(sa, sb, o1, o2, y, same_pixel)

        for (n, row), members in self.by_row.items():
            p = self.pix[ext.node_cond[n]]
            top = (row + 1) * p
            # slices of different trapezoids that touch inside one row of pixels
            inner = defaultdict(lambda: ([], []))
            for s in members:
                if s_["y2"][s] < top:
                    inner[s_["y2"][s]][0].append(s)
            for s in members:
                if s_["y1"][s] > row * p and s_["y1"][s] in inner:
                    inner[s_["y1"][s]][1].append(s)
            for y, (below, above) in inner.items():
                if above:
                    sweep(below, above, y, True)
            above = [s for s in self.by_row.get((n, row + 1), ()) if s_["y1"][s] == top]
            below = [s for s in members if s_["y2"][s] == top]
            if above and below:
                sweep(below, above, top, False)
        return (ha, hb, hg, hs, hcol, hlen), (np.array(va, dtype=np.int64), np.array(vb, dtype=np.int64),
                                          np.array(vg), np.array(vpair, dtype=np.int64), np.array(vlen), pairs), \
            (join_a, join_b), unions

    def solve(self) -> list[dict]:
        ext, case, s_ = self.ext, self.case, self.s
        (ha, hb, hg, hs, hcol, hlen), (va, vb, vg, vpair, vlen, pairs), (join_a, join_b), unions = self._links()
        cut_ids, cut_a, cut_b, cut_g = [], [], [], []
        for c in case.net.cuts:
            spec = ext.cut_specs[ext.cut_spec[c]]
            lo, up = ext.cut_lower[c], ext.cut_upper[c]
            if not spec.get("r") or not ext.conductors[ext.node_cond[lo]].get("rs") or \
                    not ext.conductors[ext.node_cond[up]].get("rs"):
                continue
            x, y = ext.cut_center[c]
            pa, pb = self.piece_at(lo, x, y), self.piece_at(up, x, y)
            if pa < 0 or pb < 0:
                raise BudgetError(f"net {case.net.name}: cut {spec['name']} at ({x * ext.dbu:.3f}, "
                                  f"{y * ext.dbu:.3f}) lands on no piece of the mesh")
            cut_ids.append(c)
            cut_a.append(pa)
            cut_b.append(pb)
            cut_g.append(ext.cut_neq[c] / spec["r"])
        a = np.concatenate([ha, va, np.array(cut_a, dtype=np.int64)])
        b = np.concatenate([hb, vb, np.array(cut_b, dtype=np.int64)])
        g = np.concatenate([hg, vg, np.array(cut_g, dtype=float)])
        n_h, n_v = len(ha), len(va)

        inject = np.zeros(self.count)
        groups = []
        for inj in case.injections:
            if inj.kind == "point":
                pix = self.piece_at(inj.node, *inj.point) if inj.node in self.nodes else -1
                if pix < 0:
                    raise BudgetError(f"net {case.net.name}: load {inj.what} is on no metal of the solve")
                inject[pix] += inj.ma
                groups.append((inj, np.array([pix])))
                continue
            idx_all, w_all = [], []
            for node, poly in inj.polys:
                if node in self.nodes:
                    idx, w = self.pieces_under(node, poly)
                    idx_all.append(idx)
                    w_all.append(w)
            idx = np.concatenate(idx_all) if idx_all else np.array([], dtype=np.int64)
            w = np.concatenate(w_all) if w_all else np.array([])
            if not len(idx):
                raise BudgetError(f"net {case.net.name}: load {inj.what} covers no piece of the solve")
            if inj.kind == "ideal":
                join_a.extend([int(idx[0])] * (len(idx) - 1))
                join_b.extend(int(i) for i in idx[1:])
                inject[idx[0]] += inj.ma
            else:
                np.add.at(inject, idx, inj.ma * w / w.sum())
            groups.append((inj, idx))
        fixed = np.zeros(self.count, dtype=bool)
        for node, region, point, name in case.sources:
            if node not in self.nodes:
                continue
            if region is not None:
                idx, _w = self.pieces_under(node, region)
                fixed[idx] = True
            else:
                pix = self.piece_at(node, *point)
                if pix < 0:
                    raise BudgetError(f"net {case.net.name}: source {name} is on no metal of the solve")
                fixed[pix] = True
        if not fixed.any():
            raise BudgetError(f"net {case.net.name}: no source on the metal of the solve (no pad, no source label)")

        # join the pieces of an ideal terminal and the pieces that touch inside a pixel, keep what a source reaches
        join = sp.coo_matrix((np.ones(len(join_a)), (join_a, join_b)), shape=(self.count, self.count))
        _n, alias = csgraph.connected_components(join, directed=False)
        m = int(alias.max()) + 1
        fixed_m = np.zeros(m, dtype=bool)
        fixed_m[alias[fixed]] = True
        inject_m = np.bincount(alias, weights=inject, minlength=m)
        am, bm = alias[a], alias[b]
        keep = am != bm
        adj = sp.coo_matrix((np.ones(int(keep.sum())), (am[keep], bm[keep])), shape=(m, m))
        _n, comp = csgraph.connected_components(adj, directed=False)
        live = np.zeros(int(comp.max()) + 1, dtype=bool)
        live[comp[fixed_m]] = True
        dead = ~live[comp]
        if (np.abs(inject_m[dead]) > 0).any():
            lost = sorted({inj.what for inj, idx in groups if dead[alias[idx]].any()})
            raise BudgetError(f"net {case.net.name}: no metal path from a source to {', '.join(lost[:5])}")
        on_source = sorted({inj.what for inj, idx in groups if fixed_m[alias[idx]].any()})
        if on_source:
            case.notes.append(f"{', '.join(on_source[:5])} touch a source, their current does not flow through "
                              f"the metal of the net")
        free = ~fixed_m & ~dead
        nf = int(free.sum())
        order = -np.ones(m, dtype=np.int64)
        order[free] = np.arange(nf)
        ga, gb, gg = am[keep], bm[keep], g[keep]
        both = free[ga] & free[gb]
        diag = np.bincount(order[ga[free[ga]]], weights=gg[free[ga]], minlength=nf) + \
            np.bincount(order[gb[free[gb]]], weights=gg[free[gb]], minlength=nf)
        rows = np.concatenate([order[ga[both]], order[gb[both]], np.arange(nf)])
        cols = np.concatenate([order[gb[both]], order[ga[both]], np.arange(nf)])
        vals = np.concatenate([-gg[both], -gg[both], diag])
        volt = np.zeros(m)
        if nf:
            lap = sp.csc_matrix((vals, (rows, cols)), shape=(nf, nf))
            volt[free] = spla.splu(lap, permc_spec="COLAMD").solve(inject_m[free] * 1e-3)
        self.nodes_solved = nf

        for inj, idx in groups:
            if len(idx):
                case.ir_mv[inj.what] = max(case.ir_mv.get(inj.what, 0.0),
                                           float(np.abs(volt[alias[idx]]).max()) * 1e3)
        current = g * (volt[am] - volt[bm]) * 1e3  # mA
        rows_h = self._h_sections(current[:n_h], hs, hcol, hlen, unions)
        rows_v = self._v_sections(current[n_h:n_h + n_v], vpair, vlen, pairs)
        return self._worst_per_tile(rows_h + rows_v) + self._cut_rows(current[n_h + n_v:], cut_ids)

    def _section_row(self, ci, current, width_dbu, slanted, box):
        # sections run along the pixel grid, so a 45 degree wire is crossed over its width times sqrt 2
        width = width_dbu * self.ext.dbu / (math.sqrt(2.0) if slanted else 1.0)
        limit = float(wire_limit(self.ext.conductors[ci]["limit"], width))
        return {"element": "wire", "layer": self.ext.conductors[ci]["name"], "width_um": width, "cuts": None,
                "current_ma": current, "limit_ma": limit, "ratio": current / limit, "box": box}

    def _h_sections(self, current, hs, hcol, hlen, unions) -> list:
        """Sections on the vertical pixel lines: links joined by the cut line passing from slice to slice."""
        if not len(hs):
            return []
        s_, ext = self.s, self.ext
        if unions:
            u = np.array(unions, dtype=np.int64)
            graph = sp.coo_matrix((np.ones(len(u)), (u[:, 0], u[:, 1])), shape=(len(hs), len(hs)))
            _n, label = csgraph.connected_components(graph, directed=False)
        else:
            label = np.arange(len(hs))
        cur = np.bincount(label, weights=np.abs(current))
        width = np.bincount(label, weights=hlen)
        slanted = np.bincount(label, weights=s_["slanted"][hs].astype(float)) > 0
        y_lo = np.full(len(cur), np.inf)
        y_hi = np.full(len(cur), -np.inf)
        np.minimum.at(y_lo, label, s_["y1"][hs])
        np.maximum.at(y_hi, label, s_["y2"][hs])
        first = np.full(len(cur), -1)
        first[label[::-1]] = np.arange(len(hs))[::-1]
        rows = []
        for k in np.nonzero(cur > 0)[0]:
            i = first[k]
            ci = ext.node_cond[int(s_["node"][hs[i]])]
            if not ext.conductors[ci].get("limit"):
                continue
            p = int(s_["pix"][hs[i]])
            x = (int(hcol[i]) + 1) * p
            box = pya.Box(x - p // 4, int(y_lo[k]), x + p // 4, int(y_hi[k]))
            rows.append(self._section_row(ci, float(cur[k]), float(width[k]), bool(slanted[k]), box) | {"dir": 0})
        return rows

    def _v_sections(self, current, vpair, vlen, pairs) -> list:
        """Sections on the horizontal pixel lines: the links of one pair of slices."""
        if not len(vpair):
            return []
        s_, ext = self.s, self.ext
        cur = np.bincount(vpair, weights=np.abs(current), minlength=len(pairs))
        width = np.bincount(vpair, weights=vlen, minlength=len(pairs))
        rows = []
        for k in np.nonzero(cur > 0)[0]:
            sa, sb, o1, o2, y = pairs[k]
            ci = ext.node_cond[int(s_["node"][sa])]
            if not ext.conductors[ci].get("limit"):
                continue
            p = int(s_["pix"][sa])
            box = pya.Box(int(o1), int(y) - p // 4, int(math.ceil(o2)), int(y) + p // 4)
            slanted = bool(s_["slanted"][sa] or s_["slanted"][sb])
            rows.append(self._section_row(ci, float(cur[k]), float(width[k]), slanted, box) | {"dir": 1})
        return rows

    def _worst_per_tile(self, rows: list) -> list:
        """The worst section per conductor, direction and tile, so one wide strap is not listed a hundred times."""
        best = {}
        dbu = self.ext.dbu
        for r in rows:
            c = r["box"].center()
            key = (r["layer"], r["dir"], int(c.x * dbu // TILE_UM), int(c.y * dbu // TILE_UM))
            if key not in best or r["ratio"] > best[key]["ratio"]:
                best[key] = r
        return list(best.values())

    def _cut_rows(self, current, cut_ids) -> list[dict]:
        ext = self.ext
        per_cut = {c: abs(float(i)) / ext.cut_neq[c] for c, i in zip(cut_ids, current)}
        rows = []
        for members in cut_arrays(ext, cut_ids):
            spec = ext.cut_specs[ext.cut_spec[members[0]]]
            if not spec.get("imax"):
                continue
            worst = max(members, key=lambda c: per_cut[c])
            box = pya.Box()
            for c in members:
                box += ext.cut_poly[c].bbox()
            rows.append({"element": "cut", "layer": spec["name"], "width_um": None,
                         "cuts": sum(ext.cut_neq[c] for c in members),
                         "current_ma": per_cut[worst], "limit_ma": spec["imax"],
                         "ratio": per_cut[worst] / spec["imax"], "box": box})
        return rows


# --- check ----------------------------------------------------------------------------------------------------------

def judge(ext, case, floor: float, pixel_um: float, max_nodes: int) -> None:
    if case.bound is None and not case.injections:
        case.status, case.stage = "no load", "-"
        return
    total = case.total_ma
    if total <= floor:
        case.status, case.stage = "pass", "floor"
        return
    failures = screen(ext, case, total)
    if not failures:
        case.status, case.stage = "pass", "screen"
        return
    if not case.placed:
        case.status, case.stage = "unresolved", "screen"
        case.notes.append(f"{len(failures)} elements cannot carry the whole {total:.3f} mA, and solving the net "
                          f"needs the current of each device")
        case.rows = [{"element": f["element"], "layer": "", "width_um": None, "cuts": None, "current_ma": total,
                      "limit_ma": None, "ratio": None, "box": f["box"]} for f in failures]
        return
    mesh = Mesh(ext, case, pixel_um, max_nodes)
    case.rows = mesh.solve()
    case.stage = f"solve ({mesh.pixel_um:.3f} um pixels, {mesh.nodes_solved} nodes)"
    worst = max((r["ratio"] for r in case.rows), default=0.0)
    case.status = "fail" if worst > 1.0 else "pass"


def fmt(value, digits=3) -> str:
    return "-" if value is None else f"{value:.{digits}f}"


def row_line(ext, case, row) -> str:
    box = row["box"]
    at = f"({box.center().x * ext.dbu:.2f}, {box.center().y * ext.dbu:.2f})"
    element = row["layer"] or row["element"]
    return (f"| {case.net.name} | {element} | {fmt(row['width_um'])} | "
            f"{row['cuts'] if row['cuts'] is not None else '-'} | {fmt(row['current_ma'], 4)} | "
            f"{fmt(row['limit_ma'], 4)} | {fmt(row['ratio'], 2)} | {at} |")


TABLE_HEAD = ["| Net | Layer | W (um) | Cuts | I avg (mA) | Limit (mA) | Ratio | At (um) |",
              "|---|---|---|---|---|---|---|---|"]


def report(ext, cases, header, floor, warn, left_out, warnings, limit) -> list[str]:
    lines = list(header)
    lines.append(f"Floor: {floor[0]:.3f} mA ({floor[1]}), a net below it passes without geometry")
    lines.extend(f"[WARNING] {w}" for w in warnings)
    lines.append("")
    lines.append("| Net | I (mA) | Verdict | Stage | Worst ratio | Source of I |")
    lines.append("|---|---|---|---|---|---|")
    # a macro on its own has a case per net, most of them pass at the floor: count those, list the others
    quiet = [c for c in cases if c.bound is not None and c.stage == "floor"]
    for case in sorted((c for c in cases if c not in quiet), key=lambda c: c.net.name):
        worst = max((r["ratio"] for r in case.rows if r["ratio"] is not None), default=None)
        lines.append(f"| {case.net.name} | {case.total_ma:.4f} | {case.status} | {case.stage} | {fmt(worst, 2)} | "
                     f"{'; '.join(case.source_texts())} |")
    if quiet:
        more = "more " if len(quiet) < len(cases) else ""
        lines.append(f"| {len(quiet)} {more}nets | at most {max(c.total_ma for c in quiet):.4f} | pass | floor | - | |")
    fails = [(c, r) for c in cases for r in c.rows if r["ratio"] is not None and r["ratio"] > 1.0]
    warns = [(c, r) for c in cases for r in c.rows if r["ratio"] is not None and warn < r["ratio"] <= 1.0]
    for title, items in ((f"Above the limit ({len(fails)})", fails),
                         (f"Between {warn} and 1 of the limit ({len(warns)})", warns)):
        if not items:
            continue
        items.sort(key=lambda cr: -cr[1]["ratio"])
        shown = items if limit == 0 else items[:limit]
        lines += ["", f"{title}:"] + TABLE_HEAD + [row_line(ext, c, r) for c, r in shown]
    worst_rows = []
    for case in cases:
        per_layer = {}
        for r in case.rows:
            if r["ratio"] is not None and (r["layer"] not in per_layer or r["ratio"] > per_layer[r["layer"]]["ratio"]):
                per_layer[r["layer"]] = r
        worst_rows += [(case, r) for r in per_layer.values()]
    if worst_rows:
        worst_rows.sort(key=lambda cr: (cr[0].net.name, -cr[1]["ratio"]))
        lines += ["", "Worst element per net and layer:"] + TABLE_HEAD + [row_line(ext, c, r) for c, r in worst_rows]
    unresolved = [c for c in cases if c.status == "unresolved"]
    if unresolved:
        lines += ["", "Unresolved (the screen fails and the currents of the devices are not known):"]
        for case in unresolved:
            lines.append(f"  {case.net.name}: {'; '.join(case.notes)}")
            for r in case.rows[:5]:
                box = r["box"]
                lines.append(f"    {r['element']} at ({box.center().x * ext.dbu:.2f}, {box.center().y * ext.dbu:.2f})")
    notes = [(c, n) for c in cases if c.status != "unresolved" for n in c.notes]
    if notes:
        lines += [""] + [f"Note on {c.net.name}: {n}" for c, n in notes]
    ir = [(c, k, v) for c in cases for k, v in c.ir_mv.items()]
    if ir:
        lines += ["", "Static IR drop at the loads (mV, from the sources of the net):"]
        for c, k, v in sorted(ir, key=lambda x: -x[2])[: (limit or len(ir))]:
            lines.append(f"  {c.net.name} {k}: {v:.2f}")
    if left_out:
        lines += ["", "Pad nets without a current in the budget (not checked): " + ", ".join(left_out)]
    return lines


def write_markers(path, ext, cases, warn) -> None:
    markers = sak_netgraph.Markers(TOOL, ext.top.name, ext.dbu)
    for case in cases:
        for r in case.rows:
            if r["ratio"] is None:
                category = "unresolved (screen fails)"
            elif r["ratio"] > 1.0:
                category = "above the limit"
            elif r["ratio"] > warn:
                category = f"between {warn} and 1 of the limit"
            else:
                continue
            text = (f"net {case.net.name}, {r['layer'] or r['element']}, I {fmt(r['current_ma'], 4)} mA, "
                    f"limit {fmt(r['limit_ma'], 4)} mA, ratio {fmt(r['ratio'], 2)}")
            markers.add(category, r["box"], text)
    markers.save(path)


def debug(args, start: float, text: str) -> None:
    if args.debug:
        print(f"[INFO] {time.time() - start:7.1f} s  {text}", file=sys.stderr, flush=True)


def cmd_check(args) -> None:
    as_json = args.json
    stack = sak_tech.stack(args.tech)
    if stack is None:
        sak_json.fail(TOOL, f"No metal stack for PDK '{args.tech}' (known: {', '.join(sorted(sak_tech.STACKS))})",
                      as_json, sak_json.EXIT_USAGE)
    if bool(args.budget) == bool(args.view):
        sak_json.fail(TOOL, "Give either -b <budget> or -v <view> with -s <state>", as_json, sak_json.EXIT_USAGE)
    if args.view and not args.state:
        sak_json.fail(TOOL, "-v needs -s <state>", as_json, sak_json.EXIT_USAGE)
    if args.pixel <= 0 or args.max_nodes <= 0 or not 0 < args.warn <= 1:
        sak_json.fail(TOOL, "--pixel and --max-nodes must be positive, --warn in (0, 1]", as_json,
                      sak_json.EXIT_USAGE)
    if not os.path.isdir(args.workdir):
        sak_json.fail(TOOL, f"Work directory {args.workdir} does not exist", as_json, sak_json.EXIT_USAGE)
    start = time.time()
    try:
        inputs = [sak_json.input_entry(args.layout)]
        black_box, keep, views, budget = [], [], [], {}
        if args.budget:
            inputs.append(sak_json.input_entry(args.budget))
            budget = read_yaml(args.budget)
            check_keys(args.budget, budget, BUDGET_KEYS)
            base = os.path.dirname(os.path.abspath(args.budget))
            black_box = names(budget.get("black_box"), f"{args.budget}, black_box")
            keep = names(budget.get("keep"), f"{args.budget}, keep")
            for entry in budget.get("views") or []:
                if not isinstance(entry, dict) or "view" not in entry or "state" not in entry:
                    raise BudgetError(f"{args.budget}: each views entry needs 'view' and 'state'")
                if not isinstance(entry["state"], str):
                    raise BudgetError(f"{args.budget}: state {entry['state']!r} of {entry['view']} is not text, "
                                      f"quote it (YAML reads on, off, yes, no and numbers as other types)")
                path = os.path.join(base, str(entry["view"]))
                inputs.append(sak_json.input_entry(path))
                views.append(read_view(path, entry["state"]))
            black_box += [v["cell"] for v in views if v["cell"] not in black_box]
        else:
            inputs.append(sak_json.input_entry(args.view))
            own = read_view(args.view, args.state)
            if gds_digest(args.layout) != own["digest"]:
                raise BudgetError(f"view {args.view} was written for {own['gds']}, not for {args.layout}")
        layout = sak_netgraph.read_layout(args.layout)
        top = sak_netgraph.pick_top(layout, args.cell, args.layout)
        ext = sak_netgraph.Extraction(layout, top, stack, black_box, keep)
        debug(args, start, f"extraction: {len(ext.node_cond)} polygons, {len(ext.cut_spec)} cuts, {len(ext.nets)} nets")
        if args.budget:
            warnings = check_views_against_chip(ext, views)
            cases, left_out, more = build_budget_cases(ext, budget, views)
            warnings += more
        else:
            if own["cell"] != top.name:
                raise BudgetError(f"view {args.view} is for cell {own['cell']}, the layout's cell is {top.name}")
            cases, left_out, warnings = build_view_cases(ext, own), [], []
        floor = floor_ma(stack)
        for case in cases:
            judge(ext, case, floor[0], args.pixel, args.max_nodes)
            debug(args, start, f"{case.net.name}: {case.total_ma:.4f} mA, {case.status} at {case.stage}")
    except (sak_json.InputError, sak_netgraph.LayoutError, BudgetError) as exc:
        sak_json.fail(TOOL, str(exc), as_json)

    seconds = round(time.time() - start, 1)
    stem = os.path.join(args.workdir, f"{top.name}_current_density")
    header = [f"Current density of {top.name} in {args.layout} (PDK {sak_tech.tech_key(args.tech)}, {seconds} s)",
              f"Limits: {stack['limits_source']}, resistance: {stack['resistance_source']}",
              f"Currents: {args.budget or (args.view + ' state ' + args.state + ', ' + own['source'])}"]
    if black_box:
        header.append(f"Black boxes: {' '.join(black_box)}" + (f", kept: {' '.join(keep)}" if keep else ""))
    with open(stem + ".rpt", "w", encoding="utf-8") as fh:
        fh.write("\n".join(report(ext, cases, header, floor, args.warn, left_out, warnings, 0)) + "\n")
    write_markers(stem + ".lyrdb", ext, cases, args.warn)

    failed = [c for c in cases if c.status == "fail"]
    body = {
        "cell": top.name, "pdk": sak_tech.tech_key(args.tech), "seconds": seconds,
        "floor_ma": floor[0], "warn": args.warn, "report": stem + ".rpt", "markers": stem + ".lyrdb",
        "nets": sak_json.cap([{
            "net": c.net.name, "current_ma": round(c.total_ma, 6), "verdict": c.status, "stage": c.stage,
            "worst_ratio": max((r["ratio"] for r in c.rows if r["ratio"] is not None), default=None),
            "sources_of_current": c.source_texts(), "notes": c.notes} for c in cases], args.max),
        "nets_total": len(cases),
        "failed": [c.net.name for c in failed],
        "unresolved": [c.net.name for c in cases if c.status == "unresolved"],
        "pad_nets_without_current": left_out, "warnings": warnings, "cap": args.max,
    }
    status = "findings" if failed else "ok"
    text = "\n".join(report(ext, cases, header, floor, args.warn, left_out, warnings, args.max)
                     + ["", f"Report: {body['report']}", f"Markers: {body['markers']}"])
    sak_json.emit(TOOL, status, inputs, body, as_json, text)
    sys.exit(sak_json.EXIT_FINDINGS if failed else sak_json.EXIT_OK)


# --- view -----------------------------------------------------------------------------------------------------------

NUMBER = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"


def read_data(path: str) -> dict:
    """Pin currents in A from lines '<pin> <value>' (or '<pin> = <value>')."""
    values = {}
    try:
        with open(path, encoding="utf-8") as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                match = re.fullmatch(rf"(\S+?)\s*=?\s*({NUMBER})", line)
                if not match:
                    raise BudgetError(f"{path}: cannot read line '{line}', expected '<pin> <ampere>'")
                values[match.group(1)] = float(match.group(2))
    except OSError as exc:
        raise BudgetError(f"cannot read {path}: {exc.strerror}") from exc
    if not values:
        raise BudgetError(f"{path} holds no '<pin> <ampere>' line")
    return values


def sta_total_power(path: str) -> float:
    """The total power (W) of the first Total line of an OpenSTA report_power."""
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                match = re.match(rf"\s*Total\s+({NUMBER})\s+({NUMBER})\s+({NUMBER})\s+({NUMBER})", line)
                if match:
                    return float(match.group(4))
    except OSError as exc:
        raise BudgetError(f"cannot read {path}: {exc.strerror}") from exc
    raise BudgetError(f"{path} has no 'Total' line of report_power")


def cell_pins(gds: str, cell: str | None, stack: dict) -> tuple[str, set]:
    layout = sak_netgraph.read_layout(gds)
    top = sak_netgraph.pick_top(layout, cell, gds)
    found = set()
    for cond in stack["conductors"]:
        for spec in (cond.get("label"), cond.get("pin")):
            if spec is None:
                continue
            li = layout.find_layer(spec[0], spec[1])
            if li is None:
                continue
            for shape in top.shapes(li).each():
                if shape.is_text():
                    found.add(shape.text.string)
    return top.name, found


def scalar(text) -> str:
    """A YAML scalar that reads back as the same text (quoted where YAML would read another type)."""
    return yaml.safe_dump(str(text), width=1000).strip().splitlines()[0]


def cmd_view(args) -> None:
    as_json = args.json
    stack = sak_tech.stack(args.tech)
    if stack is None:
        sak_json.fail(TOOL, f"No metal stack for PDK '{args.tech}' (known: {', '.join(sorted(sak_tech.STACKS))})",
                      as_json, sak_json.EXIT_USAGE)
    if sum(1 for x in (args.data, args.current, args.sta_power) if x) != 1:
        sak_json.fail(TOOL, "Give exactly one of --data, --current or --sta-power", as_json, sak_json.EXIT_USAGE)
    if args.sta_power and (not args.supply or not args.ground):
        sak_json.fail(TOOL, "--sta-power needs --supply <pin>=<V> and --ground <pin>", as_json, sak_json.EXIT_USAGE)
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.state) or yaml.safe_load(args.state) != args.state:
        sak_json.fail(TOOL, f"State '{args.state}' must be letters, digits, '_', '.' or '-' and read back as text "
                      f"in YAML (not on, off, yes, no, true, false or a number)", as_json, sak_json.EXIT_USAGE)
    try:
        inputs = [sak_json.input_entry(args.gds)]
        name, pins = cell_pins(args.gds, args.cell, stack)
        if args.data:
            inputs.append(sak_json.input_entry(args.data))
            amps = read_data(args.data)
        elif args.current:
            amps = {}
            for item in args.current:
                match = re.fullmatch(rf"(\S+)=({NUMBER})", item)
                if not match:
                    raise BudgetError(f"--current {item}: expected <pin>=<mA>")
                amps[match.group(1)] = float(match.group(2)) * 1e-3
        else:
            inputs.append(sak_json.input_entry(args.sta_power))
            match = re.fullmatch(rf"(\S+)=({NUMBER})", args.supply)
            if not match or float(match.group(2)) <= 0:
                raise BudgetError(f"--supply {args.supply}: expected <pin>=<volt> with a positive voltage")
            amp = sta_total_power(args.sta_power) / float(match.group(2))
            amps = {match.group(1): amp, args.ground: -amp}
        by_lower = {p.lower(): p for p in pins}
        pins_ma = {}
        for key, value in amps.items():
            pin = key if key in pins else by_lower.get(key.lower())
            if pin is None:
                raise BudgetError(f"'{key}' is no pin label of {name} in {args.gds} (pins: {', '.join(sorted(pins))})")
            pins_ma[pin] = value * 1e3
        digest = gds_digest(args.gds)
    except (sak_json.InputError, sak_netgraph.LayoutError, BudgetError) as exc:
        sak_json.fail(TOOL, str(exc), as_json)

    warnings = []
    balance = sum(pins_ma.values())
    if abs(balance) > 0.01 * max(abs(v) for v in pins_ma.values()) + 1e-6:
        warnings.append(f"the pin currents of state {args.state} sum to {balance:.6f} mA, not to 0")
    states = {}
    if os.path.exists(args.output):
        try:
            old = read_yaml(args.output)
        except BudgetError:
            old = {}
        if old.get("cell") == name and old.get("gds_digest") == digest:
            states = dict(old.get("states") or {})
        elif old.get("states"):
            dropped = sorted(str(s) for s in old["states"] if str(s) != args.state)
            if dropped:
                warnings.append(f"the GDS changed since {args.output} was written, its states "
                                f"{', '.join(dropped)} are dropped, write them again")
    states[args.state] = {"source": args.source, "pins_ma": pins_ma}
    rel = os.path.relpath(os.path.abspath(args.gds), os.path.dirname(os.path.abspath(args.output)))
    lines = [f"# Current view of {name}: the average current into each pin (mA) per state.",
             f"# Written by {TOOL}.py view, do not edit, write it again instead.",
             f"cell: {scalar(name)}", f"gds: {scalar(rel)}", f"gds_digest: {digest}", "states:"]
    for state in sorted(states, key=str):
        entry = states[state]
        lines.append(f"  {scalar(state)}:")
        lines.append(f"    source: {scalar(entry.get('source', ''))}")
        lines.append("    pins_ma:")
        for pin in sorted(entry.get("pins_ma") or {}, key=str):
            lines.append(f"      {scalar(pin)}: {float(entry['pins_ma'][pin]):.6g}")
    try:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    except OSError as exc:
        sak_json.fail(TOOL, f"cannot write {args.output}: {exc.strerror}", as_json, sak_json.EXIT_USAGE)
    body = {"view": args.output, "cell": name, "state": args.state, "pins_ma": pins_ma, "warnings": warnings}
    text = "\n".join([f"[WARNING] {w}" for w in warnings]
                     + [f"Wrote state {args.state} of {name} to {args.output}: "
                        + ", ".join(f"{p} {v:.6g} mA" for p, v in sorted(pins_ma.items()))])
    sak_json.emit(TOOL, "ok", inputs, body, as_json, text)


def main() -> None:
    parser = sak_json.SakArgumentParser(tool=TOOL, description="Check the DC current density of the wires and cuts "
                                        "of a layout against the PDK limits, or write a current view.")
    # the subcommand parsers are SakArgumentParsers too and bring their own --json and --max
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check", help="check a layout", tool=TOOL)
    check.add_argument("layout", help="GDS2 or OASIS layout (optionally gzipped)")
    check.add_argument("-t", "--tech", default=os.getenv("PDK"), metavar="PDK",
                       help="PDK of the metal stack (default: environment variable PDK)")
    check.add_argument("-c", "--cell", metavar="CELL", help="cell to check (default: the single top cell)")
    check.add_argument("-b", "--budget", metavar="YAML", help="current budget of a chip")
    check.add_argument("-v", "--view", metavar="YAML", help="current view of the cell itself (a macro)")
    check.add_argument("-s", "--state", metavar="STATE", help="state of the view")
    check.add_argument("--pixel", type=float, default=0.5, metavar="UM",
                       help="pixel of the resistive solve on the thin metals (default: 0.5)")
    check.add_argument("--max-nodes", type=int, default=1000000, metavar="N",
                       help="raise the pixel until one net has at most N mesh nodes (default: 1000000)")
    check.add_argument("--warn", type=float, default=0.5, metavar="RATIO",
                       help="list elements above this fraction of their limit as warnings (default: 0.5)")
    check.add_argument("-w", "--workdir", default=".", metavar="DIR",
                       help="directory for the report and the marker database (default: current directory)")
    check.add_argument("-d", "--debug", action="store_true", help="print the time of each stage on stderr")
    view = sub.add_parser("view", help="write a current view", tool=TOOL)
    view.add_argument("-o", "--output", required=True, metavar="YAML", help="view file to write or update")
    view.add_argument("--gds", required=True, help="GDS of the cell, its digest goes into the view")
    view.add_argument("--cell", help="cell in the GDS (default: the single top cell)")
    view.add_argument("--state", required=True, help="name of the operating state")
    view.add_argument("--source", required=True, help="where the currents come from (bench, corner, temperature)")
    view.add_argument("-t", "--tech", default=os.getenv("PDK"), metavar="PDK",
                      help="PDK of the pin label layers (default: environment variable PDK)")
    view.add_argument("--data", metavar="FILE", help="lines '<pin> <ampere>', current into the cell positive")
    view.add_argument("--current", action="append", metavar="PIN=MA", help="a pin current in mA (repeatable)")
    view.add_argument("--sta-power", metavar="REPORT", help="OpenSTA report_power, its total power")
    view.add_argument("--supply", metavar="PIN=V", help="supply pin and voltage for --sta-power")
    view.add_argument("--ground", metavar="PIN", help="ground pin for --sta-power")
    args = parser.parse_args()
    # a --json before the subcommand lands in the main parser, whose value the subcommand's default overwrites
    args.json = args.json or "--json" in sys.argv[1:]
    if args.command == "check":
        cmd_check(args)
    else:
        cmd_view(args)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
