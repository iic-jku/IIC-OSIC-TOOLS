#!/usr/bin/env python3
# ========================================================================
# Render a layout (GDS2/OASIS) to PNG images using KLayout and the
# layer colors of the PDK
#
# SPDX-FileCopyrightText: 2026 Simon Dorrer
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
# Usage: sak-render.py [-t <tech>] [-l <layers>] [-x <layers>] [--list]
#                      [-o <image>] [-b both|white|black] [-c <cellname>]
#                      [-w <px>] [--height <px>] [-s <n>] [-d]
#                      [--bbox=<x1,y1,x2,y2>] [--json] <layout>
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

"""Render a layout (GDS2/OASIS, optionally gzipped) to PNG images.

The layout is drawn with the layer colors and stipples of the PDK's own
KLayout layer properties (`.lyp`), flattened over the full hierarchy and
cropped to the drawn geometry, so the image has no border margin. Two
images are written by default, one on white and one on black background
(`<name>_white.png` and `<name>_black.png`), since either may suit a paper,
a slide deck or a dark web page better. `-b white` or `-b black` picks one
and then writes exactly the requested file name.

Supported technologies (`-t`, or the `$PDK` environment variable as set in
the IIC-OSIC-TOOLS container):

    ihp-sg13g2      (alias sg13g2)
    ihp-sg13cmos5l  (aliases sg13cmos5l, cmos5l)
    gf180mcuD       (aliases gf180mcu, gf180)
    sky130A         (alias sky130)

By default all physical mask layers of the technology are rendered:
wells, implants, active, poly, contacts, the full metal/via stack, MIM
caps and the pad opening. Text, pins, markers, boundaries and fill/dummy
shapes stay hidden. `-l` narrows or extends that:

    -l <layers>   render exactly these layers instead of the default set
    -x <layers>   hide these layers (applied after -l)
    --list        show every selectable layer and group of the technology

`<layers>` is a comma-separated list (the option can also be repeated) of

    groups        active, cont, filler, implant, metal, mim, pad, poly,
                  res, seal, via, well. `metal` is every metal of the
                  stack. A group wins over a layer of the same name, so
                  sky130A's met1-met2 via layer is reachable as `via1`.
    layer names   as printed by --list, case-insensitive, `-`, `_` and
                  `.` are ignored: Metal1, m1, TopMetal2, tm2, met1, li1,
                  Activ, COMP, diff, capm, ... A name from the PDK's
                  `.lyp` file (e.g. `Metal1.slit`) also works.
    numbers       GDS layer/datatype pairs like `8/0`. A plain `8` is
                  short for `8/0`, and `8/*` is every datatype of layer
                  8 that the PDK defines.
    all           every layer known to this script, fill included
    default       the default set described above

A token prefixed with `+` adds to the default set instead of replacing
it, so the common cases stay short:

    sak-render.py chip_top.gds.gz              # every physical layer
    sak-render.py -l metal,via chip.gds        # the routing stack only
    sak-render.py -l m3 chip.gds               # a single layer
    sak-render.py -l +filler chip.gds          # default plus metal fill
    sak-render.py -l all chip.gds              # everything, fill included
    sak-render.py -x well,implant chip.gds     # default minus those
    sak-render.py -l 134/0,134/22 chip.gds     # by GDS numbers

The image is 1024 pixels wide unless `-w`/`--height` say otherwise, and
the missing dimension follows from the aspect ratio of the rendered
geometry.
When both are given, the geometry is fitted inside and the rest stays
background. `-s` renders with n-times oversampling (anti-aliasing).
Rendering happens off-screen, no display is needed.

`--bbox=<x1,y1,x2,y2>` renders that region (micrometers) instead of the
drawn extent, e.g. to zoom into a cell corner. Use the `=` form, since a
leading minus sign (`--bbox=-1,-1,2,2`) would otherwise be read as an option.

`--json` prints exactly one JSON object on stdout and sends every other
message to stderr, on success and on failure. It carries `schema`, `tool`,
`status`, `input`, `bbox_um` (the rendered region), `um_per_px` (the scale)
and `files` (`path`, `background`, `width_px` and `height_px` of every image).
On failure `status` is `error` and `error` holds the message.

Usage:
    sak-render.py [-t <tech>] [-l <layers>] [-x <layers>] [--list]
                  [-o <image>] [-b both|white|black] [-c <cellname>]
                  [-w <px>] [--height <px>] [-s <n>] [-d]
                  [--bbox=<x1,y1,x2,y2>] [--json] <layout>

Return codes for script automation:
  0 = image(s) written (or --list printed)
  non-zero = error (bad arguments, file, cell or layer not found, ...)
"""

import argparse
import difflib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # pylint: disable=wrong-import-position

ERR_NONE = 0
ERR_FAIL = 1
TOOL = "sak-render"

# Set by --json: messages go to stderr and failures print the error object.
JSON_MODE = False

# KLayout provides the same API as the module 'pya' (the name used inside
# the KLayout application) and as the standalone modules 'klayout.lay' /
# 'klayout.db'. The container puts the KLayout pymod on PYTHONPATH, so a
# plain python3 finds it. Inside the application 'pya' carries LayoutView
# as well.
try:
    import klayout.lay as klay
    import klayout.db as kdb
except ImportError:
    try:
        import pya as klay
        kdb = klay
        klay.LayoutView
    except (ImportError, AttributeError):
        sak_json.fail(TOOL, "KLayout Python module not found "
                      "(tried 'klayout.lay'/'klayout.db' and 'pya')!",
                      "--json" in sys.argv[1:], ERR_FAIL)

BACKGROUNDS = {"white": "#FFFFFF", "black": "#000000"}

# One entry per selectable layer of a technology:
#
#     (name, GDS layer, GDS datatype, groups, on, aliases)
#
# `name` and `aliases` are what -l/-x accept (matching is case-insensitive
# and ignores `-`, `_` and `.`), `groups` are the group tokens the layer
# belongs to, and `on` marks the default render set: the physical mask
# layers, without fill/dummy shapes and without helper layers. The entries
# are only selectors. Colors, stipples and stacking order come from the
# PDK's .lyp file, of which the layers here are a curated subset. Any
# other .lyp entry stays selectable by its .lyp name or layer/datatype
# numbers.
TECHS = {
    "ihp-sg13g2": {
        "aliases": ("sg13g2",),
        "lyp": ("libs.tech", "klayout", "tech", "sg13g2.lyp"),
        "layers": (
            ("NWell",             31,  0, ("well",),    True,  ()),
            ("PWell",             46,  0, ("well",),    False, ()),
            ("isoNWell",         257,  0, ("well",),    False, ()),
            ("nBuLay",            32,  0, ("well",),    True,  ()),
            ("Substrate",         40,  0, (),           False, ()),
            ("ThickGateOx",       44,  0, ("implant",), True,  ()),
            ("nSD",                7,  0, ("implant",), True,  ()),
            ("pSD",               14,  0, ("implant",), True,  ()),
            ("SalBlock",          28,  0, ("implant",), True,  ()),
            ("Activ",              1,  0, ("active",),  True,  ()),
            ("GatPoly",            5,  0, ("poly",),    True,  ()),
            ("PolyRes",          128,  0, ("res",),     False, ()),
            ("Cont",               6,  0, ("cont",),    True,  ()),
            ("Metal1",             8,  0, ("metal",),   True,  ("m1", "met1")),
            ("Via1",              19,  0, ("via",),     True,  ("v1",)),
            ("Metal2",            10,  0, ("metal",),   True,  ("m2", "met2")),
            ("Via2",              29,  0, ("via",),     True,  ("v2",)),
            ("Metal3",            30,  0, ("metal",),   True,  ("m3", "met3")),
            ("Via3",              49,  0, ("via",),     True,  ("v3",)),
            ("Metal4",            50,  0, ("metal",),   True,  ("m4", "met4")),
            ("Via4",              66,  0, ("via",),     True,  ("v4",)),
            ("Metal5",            67,  0, ("metal",),   True,  ("m5", "met5")),
            ("MIM",               36,  0, ("mim",),     True,  ()),
            ("Vmim",             129,  0, ("mim",),     True,  ()),
            ("TopVia1",          125,  0, ("via",),     True,  ("tv1",)),
            ("TopMetal1",        126,  0, ("metal",),   True,  ("tm1",)),
            ("TopVia2",          133,  0, ("via",),     True,  ("tv2",)),
            ("TopMetal2",        134,  0, ("metal",),   True,  ("tm2",)),
            ("Passiv",             9,  0, ("pad",),     True,  ()),
            ("EdgeSeal",          39,  0, ("seal",),    False, ()),
            ("Activ.filler",       1, 22, ("filler",),  False, ()),
            ("GatPoly.filler",     5, 22, ("filler",),  False, ()),
            ("Metal1.filler",      8, 22, ("filler",),  False, ()),
            ("Metal2.filler",     10, 22, ("filler",),  False, ()),
            ("Metal3.filler",     30, 22, ("filler",),  False, ()),
            ("Metal4.filler",     50, 22, ("filler",),  False, ()),
            ("Metal5.filler",     67, 22, ("filler",),  False, ()),
            ("TopMetal1.filler", 126, 22, ("filler",),  False, ()),
            ("TopMetal2.filler", 134, 22, ("filler",),  False, ()),
        ),
    },
    "ihp-sg13cmos5l": {
        "aliases": ("sg13cmos5l", "cmos5l"),
        "lyp": ("libs.tech", "klayout", "tech", "sg13cmos5l.lyp"),
        "layers": (
            ("NWell",             31,  0, ("well",),    True,  ()),
            ("PWell",             46,  0, ("well",),    False, ()),
            ("Substrate",         40,  0, (),           False, ()),
            ("ThickGateOx",       44,  0, ("implant",), True,  ()),
            ("nSD",                7,  0, ("implant",), True,  ()),
            ("pSD",               14,  0, ("implant",), True,  ()),
            ("SalBlock",          28,  0, ("implant",), True,  ()),
            ("Activ",              1,  0, ("active",),  True,  ()),
            ("GatPoly",            5,  0, ("poly",),    True,  ()),
            ("PolyRes",          128,  0, ("res",),     False, ()),
            ("Cont",               6,  0, ("cont",),    True,  ()),
            ("Metal1",             8,  0, ("metal",),   True,  ("m1", "met1")),
            ("Via1",              19,  0, ("via",),     True,  ("v1",)),
            ("Metal2",            10,  0, ("metal",),   True,  ("m2", "met2")),
            ("Via2",              29,  0, ("via",),     True,  ("v2",)),
            ("Metal3",            30,  0, ("metal",),   True,  ("m3", "met3")),
            ("Via3",              49,  0, ("via",),     True,  ("v3",)),
            ("Metal4",            50,  0, ("metal",),   True,  ("m4", "met4")),
            ("TopVia1",          125,  0, ("via",),     True,  ("tv1",)),
            ("TopMetal1",        126,  0, ("metal",),   True,  ("tm1",)),
            ("Passiv",             9,  0, ("pad",),     True,  ()),
            ("EdgeSeal",          39,  0, ("seal",),    False, ()),
            ("Activ.filler",       1, 22, ("filler",),  False, ()),
            ("GatPoly.filler",     5, 22, ("filler",),  False, ()),
            ("Metal1.filler",      8, 22, ("filler",),  False, ()),
            ("Metal2.filler",     10, 22, ("filler",),  False, ()),
            ("Metal3.filler",     30, 22, ("filler",),  False, ()),
            ("Metal4.filler",     50, 22, ("filler",),  False, ()),
            ("TopMetal1.filler", 126, 22, ("filler",),  False, ()),
        ),
    },
    "gf180mcuD": {
        "aliases": ("gf180mcu", "gf180"),
        "lyp": ("libs.tech", "klayout", "tech", "gf180mcu.lyp"),
        "layers": (
            ("DNWELL",            12,  0, ("well",),    True,  ()),
            ("Nwell",             21,  0, ("well",),    True,  ()),
            ("LVPWELL",          204,  0, ("well",),    True,  ()),
            ("Dualgate",          55,  0, ("implant",), True,  ()),
            ("NAT",                5,  0, ("implant",), True,  ()),
            ("Nplus",             32,  0, ("implant",), True,  ()),
            ("Pplus",             31,  0, ("implant",), True,  ()),
            ("MVSD",             210,  0, ("implant",), True,  ()),
            ("MVPSD",             11, 39, ("implant",), True,  ()),
            ("ESD",               24,  0, ("implant",), True,  ()),
            ("SAB",               49,  0, ("implant",), True,  ()),
            ("COMP",              22,  0, ("active",),  True,  ()),
            ("Poly2",             30,  0, ("poly",),    True,  ()),
            ("Resistor",          62,  0, ("res",),     True,  ()),
            ("Contact",           33,  0, ("cont",),    True,  ()),
            ("Metal1",            34,  0, ("metal",),   True,  ("m1", "met1")),
            ("Via1",              35,  0, ("via",),     True,  ("v1",)),
            ("Metal2",            36,  0, ("metal",),   True,  ("m2", "met2")),
            ("Via2",              38,  0, ("via",),     True,  ("v2",)),
            ("Metal3",            42,  0, ("metal",),   True,  ("m3", "met3")),
            ("Via3",              40,  0, ("via",),     True,  ("v3",)),
            ("Metal4",            46,  0, ("metal",),   True,  ("m4", "met4")),
            ("Via4",              41,  0, ("via",),     True,  ("v4",)),
            ("Metal5",            81,  0, ("metal",),   True,  ("m5", "met5")),
            ("FuseTop",           75,  0, ("mim",),     True,  ()),
            ("Pad",               37,  0, ("pad",),     True,  ()),
            ("COMP_Dummy",        22,  4, ("filler",),  False, ()),
            ("Poly2_Dummy",       30,  4, ("filler",),  False, ()),
            ("Metal1_Dummy",      34,  4, ("filler",),  False, ()),
            ("Metal2_Dummy",      36,  4, ("filler",),  False, ()),
            ("Metal3_Dummy",      42,  4, ("filler",),  False, ()),
            ("Metal4_Dummy",      46,  4, ("filler",),  False, ()),
            ("Metal5_Dummy",      81,  4, ("filler",),  False, ()),
        ),
    },
    "sky130A": {
        "aliases": ("sky130",),
        "lyp": ("libs.tech", "klayout", "tech", "sky130A.lyp"),
        "layers": (
            ("dnwell",            64, 18, ("well",),    True,  ()),
            ("nwell",             64, 20, ("well",),    True,  ()),
            ("pwell",             64, 44, ("well",),    False, ()),
            ("nsdm",              93, 44, ("implant",), True,  ()),
            ("psdm",              94, 20, ("implant",), True,  ()),
            ("lvtn",             125, 44, ("implant",), True,  ()),
            ("hvtp",              78, 44, ("implant",), True,  ()),
            ("hvtr",              18, 20, ("implant",), False, ()),
            ("hvi",               75, 20, ("implant",), True,  ()),
            ("vhvi",              74, 21, ("implant",), False, ()),
            ("hvntm",            125, 20, ("implant",), True,  ()),
            ("ldntm",             11, 44, ("implant",), True,  ()),
            ("tunm",              80, 20, ("implant",), True,  ()),
            ("diff",              65, 20, ("active",),  True,  ()),
            ("tap",               65, 44, ("active",),  True,  ()),
            ("poly",              66, 20, ("poly",),    True,  ()),
            ("rpm",               86, 20, ("res",),     True,  ()),
            ("urpm",              79, 20, ("res",),     True,  ()),
            ("licon1",            66, 44, ("cont",),    True,  ("licon",)),
            ("npc",               95, 20, ("cont",),    True,  ()),
            ("li1",               67, 20, ("metal",),   True,  ("li",)),
            ("mcon",              67, 44, ("via",),     True,  ()),
            ("met1",              68, 20, ("metal",),   True,  ("m1", "metal1")),
            ("via",               68, 44, ("via",),     True,  ("v1", "via1")),
            ("met2",              69, 20, ("metal",),   True,  ("m2", "metal2")),
            ("via2",              69, 44, ("via",),     True,  ("v2",)),
            ("met3",              70, 20, ("metal",),   True,  ("m3", "metal3")),
            ("via3",              70, 44, ("via",),     True,  ("v3",)),
            ("met4",              71, 20, ("metal",),   True,  ("m4", "metal4")),
            ("via4",              71, 44, ("via",),     True,  ("v4",)),
            ("met5",              72, 20, ("metal",),   True,  ("m5", "metal5")),
            ("capm",              89, 44, ("mim",),     True,  ()),
            ("capm2",             97, 44, ("mim",),     True,  ("cap2m",)),
            ("pad",               76, 20, ("pad",),     True,  ()),
            ("rdl",               74, 20, ("metal",),   False, ()),
            ("fomfill",           23, 28, ("filler",),  False, ()),
            ("polyfill",          28, 28, ("filler",),  False, ()),
            ("li1fill",           56, 28, ("filler",),  False, ()),
            ("met1fill",          36, 28, ("filler",),  False, ()),
            ("met2fill",          41, 28, ("filler",),  False, ()),
            ("met3fill",          34, 28, ("filler",),  False, ()),
            ("met4fill",          51, 28, ("filler",),  False, ()),
            ("met5fill",          59, 28, ("filler",),  False, ()),
        ),
    },
}

LAYOUT_SUFFIXES = (".gds.gz", ".oas.gz", ".gds2", ".oasis", ".gds", ".oas")


def die(msg):
    """Print an error message and terminate with the error return code."""
    if JSON_MODE:
        sak_json.fail(TOOL, msg, True, ERR_FAIL)
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(ERR_FAIL)


def info(msg):
    """Print a progress message, on stderr with --json to keep stdout clean."""
    print(msg, file=sys.stderr if JSON_MODE else sys.stdout)


class RenderArgumentParser(argparse.ArgumentParser):
    """ArgumentParser that prints the error object for a usage error with --json.

    The exit code stays the one of argparse (2).
    """

    def error(self, message):
        self.print_usage(sys.stderr)
        if "--json" in sys.argv[1:]:
            sak_json.fail(TOOL, message, True, 2)
        self.exit(2, f"{self.prog}: error: {message}\n")


def parse_bbox(text):
    """The --bbox value `x1,y1,x2,y2` as a DBox in micrometers."""
    try:
        x1, y1, x2, y2 = (float(v) for v in text.split(","))
    except ValueError:
        die(f"--bbox '{text}' is not four comma-separated numbers "
            f"(x1,y1,x2,y2 in um)")
    if x2 <= x1 or y2 <= y1:
        die(f"--bbox '{text}' is an empty region (need x2 > x1 and y2 > y1)")
    return kdb.DBox(x1, y1, x2, y2)


def norm(token):
    """Normalize a layer/group token for matching.

    Matching is case-insensitive and ignores the separators `-`, `_` and
    `.`, so `TopMetal2`, `topmetal2` and `top_metal2` are the same token,
    and the `.lyp` name `Metal1.slit` can be typed as `metal1slit` too.
    """
    return re.sub(r"[-_.\s]", "", token.lower())


def resolve_tech(name):
    """Map a -t/$PDK value onto a technology table entry."""
    wanted = norm(name)
    for tech, table in TECHS.items():
        if wanted == norm(tech) or wanted in (norm(a) for a in table["aliases"]):
            return tech
    die(f"Unsupported technology '{name}' (supported: {', '.join(TECHS)}).")
    return None  # unreachable, die() exits


def strip_layout_suffix(filename):
    """The file name without its layout extension (also `.gds.gz` etc.)."""
    lower = filename.lower()
    for suffix in LAYOUT_SUFFIXES:
        if lower.endswith(suffix) and len(filename) > len(suffix):
            return filename[: -len(suffix)]
    return os.path.splitext(filename)[0]


def lyp_names_of(lyp):
    """The normalized names a .lyp entry is selectable by.

    IHP names its entries `Metal1.drawing`, sky130A appends the numbers
    (`met1.drawing - 68/20`), and gf180mcu leaves the name empty and
    carries `Metal1` in the source specification instead. Both the
    display name (up to the ` - ` suffix) and the source name count.
    """
    names = set()
    display = (lyp.name or "").split(" - ")[0].strip()
    if display:
        names.add(norm(display))
    source = (lyp.source_name or "").strip()
    if source:
        names.add(norm(source))
    return names


def build_selector(tech):
    """Lookup tables for -l/-x tokens of one technology.

    Returns (by_token, by_group, defaults, all_pairs). Token and group
    names map onto sets of (layer, datatype) pairs.
    """
    table = TECHS[tech]
    by_token = {}
    by_group = {}
    defaults = set()
    all_pairs = set()
    for name, layer, datatype, groups, on, aliases in table["layers"]:
        pair = (layer, datatype)
        all_pairs.add(pair)
        if on:
            defaults.add(pair)
        for token in (name,) + aliases:
            by_token.setdefault(norm(token), set()).add(pair)
        for group in groups:
            by_group.setdefault(norm(group), set()).add(pair)
    return by_token, by_group, defaults, all_pairs


def resolve_token(token, tech, view):
    """The set of (layer, datatype) pairs one -l/-x token stands for.

    Resolution order: `all`/`default`, group, layer name or alias, name
    from the PDK's .lyp file, GDS `layer[/datatype]` numbers (`8` means
    `8/0`, `8/*` every datatype of layer 8 the .lyp defines). Unknown
    tokens abort with suggestions, a typo silently rendering the wrong
    layers helps nobody.
    """
    by_token, by_group, defaults, all_pairs = build_selector(tech)
    wanted = norm(token)
    if wanted == "all":
        return set(all_pairs)
    if wanted == "default":
        return set(defaults)
    if wanted in by_group:
        return set(by_group[wanted])
    if wanted in by_token:
        return set(by_token[wanted])

    # A name straight from the PDK's .lyp file (e.g. `Metal1.slit`).
    pairs = set()
    for lyp in view.each_layer():
        if lyp.source_layer >= 0 and wanted in lyp_names_of(lyp):
            pairs.add((lyp.source_layer, lyp.source_datatype))
    if pairs:
        return pairs

    match = re.fullmatch(r"(\d+)(?:/(\d+|\*))?", token.strip())
    if match:
        layer = int(match.group(1))
        if match.group(2) == "*":
            pairs = {(lyp.source_layer, lyp.source_datatype)
                     for lyp in view.each_layer()
                     if lyp.source_layer == layer}
            if not pairs:
                die(f"Layer {layer} is not in the {tech} layer properties.")
            return pairs
        datatype = int(match.group(2) or 0)
        for lyp in view.each_layer():
            if (lyp.source_layer, lyp.source_datatype) == (layer, datatype):
                return {(layer, datatype)}
        die(f"Layer {layer}/{datatype} is not in the {tech} layer "
            f"properties, so no display style exists for it.")

    known = set(by_group) | set(by_token) | {"all", "default"}
    hint = difflib.get_close_matches(wanted, sorted(known), n=3)
    hint = f" Did you mean: {', '.join(hint)}?" if hint else ""
    die(f"Unknown layer or group '{token}' for {tech} (see --list).{hint}")
    return None  # unreachable, die() exits


def split_tokens(values):
    """Flatten repeatable, comma-separated option values into tokens."""
    tokens = []
    for value in values or []:
        tokens.extend(t.strip() for t in value.split(",") if t.strip())
    return tokens


def resolve_selection(include, exclude, tech, view):
    """The (layer, datatype) pairs to render.

    Without -l the default set is used. -l replaces it, except that
    tokens prefixed with `+` only add: `-l +filler` is the default set
    plus the fill shapes. -x is subtracted at the end.
    """
    _, _, defaults, _ = build_selector(tech)
    include_tokens = split_tokens(include)
    if include_tokens:
        additive = all(t.startswith("+") for t in include_tokens)
        selected = set(defaults) if additive else set()
        for token in include_tokens:
            selected |= resolve_token(token.lstrip("+"), tech, view)
    else:
        selected = set(defaults)
    for token in split_tokens(exclude):
        selected -= resolve_token(token.lstrip("+"), tech, view)
    if not selected:
        die("The selection leaves no layer to render.")
    return selected


def list_layers(tech, pdk_root):
    """Print the selectable layers and groups of a technology (--list)."""
    table = TECHS[tech]
    lyp_path = os.path.join(pdk_root, tech, *table["lyp"])
    print(f"[INFO] Technology {tech} (layer properties: {lyp_path})")
    print(f"{'name':<18} {'layer/dt':>9}  {'default':<8} groups (aliases)")
    groups = set()
    for name, layer, datatype, layer_groups, on, aliases in table["layers"]:
        groups.update(layer_groups)
        extra = f" ({', '.join(aliases)})" if aliases else ""
        print(f"{name:<18} {f'{layer}/{datatype}':>9}  "
              f"{'on' if on else 'off':<8} {' '.join(layer_groups)}{extra}")
    print(f"\nGroups: {', '.join(sorted(groups))}")
    print("Special: all, default, +<token> (add to default), "
          "<layer>[/<datatype>], <layer>/*,")
    print("         and any layer name from the .lyp file "
          "(e.g. Metal1.slit, met1.pin).")


def resolve_cell(layout, path, name):
    """The cell to render, either by name or as the single top cell.

    ``Layout.top_cell()`` raises when a layout has more than one top
    cell, which is a common situation (e.g. leftover cells in a library
    GDS), so ``top_cells()`` is used and the ambiguity is reported
    instead.
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
        shown = [c.name for c in tops[:8]]
        if len(tops) > len(shown):
            shown.append("...")
        die(f"{path} has {len(tops)} top cells ({', '.join(shown)}); "
            f"select one with -c!")
    return tops[0]


def visible_bbox(layout, cell, selected):
    """Bounding box of the selected layers only, in micrometers.

    The cell bounding box would also cover invisible helper layers
    (markers, boundaries, text) and leave a border margin around the
    drawn geometry. On a full chip the visible outermost structure is
    the sealring, and the image is cropped to exactly that.
    """
    bbox = kdb.DBox()
    for layer, datatype in selected:
        index = layout.find_layer(layer, datatype)
        if index is not None:
            bbox += cell.dbbox(index)
    return bbox


def image_size(bbox, width, height):
    """The image dimensions, deriving the missing one from the aspect."""
    # A degenerate (line- or point-shaped) bounding box falls back to a
    # square image instead of dividing by zero.
    aspect = bbox.width() / bbox.height() if bbox.height() > 0 else 0.0
    if aspect <= 0:
        aspect = 1.0
    if not width and not height:
        width = 1024
    if not height:
        height = max(1, round(width / aspect))
    if not width:
        width = max(1, round(height * aspect))
    return width, height


def output_paths(output, layout_path, backgrounds):
    """The image file(s) to write, one per background.

    Without -o the images land in the current directory, named after the
    layout, and -o naming a directory puts them there. With both
    backgrounds the base name gets a `_white`/`_black` suffix. A single
    background writes exactly the requested name.
    """
    stem = strip_layout_suffix(os.path.basename(layout_path))
    if output and (os.path.isdir(output) or output.endswith(("/", os.sep))):
        output = os.path.join(output, stem + ".png")
    out = output or stem + ".png"
    base = out[:-4] if out.lower().endswith(".png") else out
    parent = os.path.dirname(base)
    if parent and not os.path.isdir(parent):
        die(f"Output directory '{parent}' does not exist!")
    if len(backgrounds) == 1:
        return {backgrounds[0]: base + ".png"}
    return {bg: f"{base}_{bg}.png" for bg in backgrounds}


def main():
    global JSON_MODE  # pylint: disable=global-statement
    parser = RenderArgumentParser(
        description="Render a layout (GDS2/OASIS, optionally gzipped) to "
                    "PNG images with the layer colors of the PDK "
                    "(ICD@JKU). By default all physical mask layers are "
                    "drawn on a white and on a black background, cropped "
                    "to the drawn geometry.",
        epilog="Return codes: 0 = image(s) written, non-zero = error.")
    parser.add_argument("layout", nargs="?",
                        help="Input layout (GDS2/OASIS, optionally gzipped)")
    parser.add_argument("-t", "--tech", default=os.getenv("PDK"),
                        help="Technology: ihp-sg13g2, ihp-sg13cmos5l, "
                             "gf180mcuD or sky130A "
                             "(default: environment variable PDK)")
    parser.add_argument("-l", "--layers", action="append", metavar="LAYERS",
                        help="Comma-separated layers/groups to render "
                             "instead of the default set, +<token> adds "
                             "to the default set (see --list)")
    parser.add_argument("-x", "--exclude", action="append", metavar="LAYERS",
                        help="Comma-separated layers/groups to hide, "
                             "applied after -l")
    parser.add_argument("--list", action="store_true",
                        help="List the selectable layers and groups of the "
                             "technology, then exit")
    parser.add_argument("-o", "--output", metavar="IMAGE",
                        help="Output image name, or a directory to put it "
                             "in (default: layout name with .png, in the "
                             "current directory)")
    parser.add_argument("-b", "--background", default="both",
                        choices=("both", "white", "black"),
                        help="Background color, 'both' writes *_white.png "
                             "and *_black.png (default: both)")
    parser.add_argument("-c", "--cell",
                        help="Cell to render (default: the single top cell)")
    parser.add_argument("-w", "--width", type=int,
                        help="Image width in pixels (default: 1024, or "
                             "derived from --height)")
    parser.add_argument("--height", type=int,
                        help="Image height in pixels (default: derived "
                             "from the width via the aspect ratio)")
    parser.add_argument("-s", "--oversampling", type=int, default=1,
                        metavar="N",
                        help="Render with N-times oversampling (default: 1)")
    parser.add_argument("-d", "--debug", action="store_true",
                        help="Enable debug information")
    parser.add_argument("--bbox", metavar="X1,Y1,X2,Y2",
                        help="Render this region (micrometers) instead of "
                             "the drawn extent. Write it as --bbox=... , "
                             "a leading minus sign needs the = form")
    parser.add_argument("--json", action="store_true",
                        help="Print one JSON object with the written "
                             "files on stdout, all messages go to stderr")
    args = parser.parse_args()
    JSON_MODE = args.json
    if args.bbox:
        args.bbox = parse_bbox(args.bbox)

    if not args.tech:
        die("No technology given: use -t or set the PDK environment "
            f"variable (supported: {', '.join(TECHS)}).")
    tech = resolve_tech(args.tech)
    pdk_root = os.getenv("PDK_ROOT", "/foss/pdks")

    if args.list:
        if args.json:
            die("--list cannot be combined with --json.")
        list_layers(tech, pdk_root)
        sys.exit(ERR_NONE)

    if not args.layout:
        parser.error("the layout argument is required (or use --list)")
    if (args.width is not None and args.width < 1) or \
            (args.height is not None and args.height < 1):
        die("Image width and height must be positive!")
    if args.oversampling < 1:
        die("The oversampling factor must be positive!")
    if not os.path.isfile(args.layout):
        die(f"File {args.layout} not found!")
    lyp_path = os.path.join(pdk_root, tech, *TECHS[tech]["lyp"])
    if not os.path.isfile(lyp_path):
        die(f"Layer properties {lyp_path} not found "
            f"(is PDK_ROOT set correctly?)!")

    backgrounds = (["white", "black"] if args.background == "both"
                   else [args.background])
    outputs = output_paths(args.output, args.layout, backgrounds)

    view = klay.LayoutView()
    view.set_config("grid-visible", "false")
    view.set_config("grid-show-ruler", "false")
    view.set_config("text-visible", "false")
    try:
        view.load_layout(args.layout, 0)
    except Exception as e:  # KLayout raises a plain RuntimeError here
        die(f"Cannot read {args.layout}: {e}")
    view.load_layer_props(lyp_path)

    selected = resolve_selection(args.layers, args.exclude, tech, view)
    if args.debug:
        by_token, _, _, _ = build_selector(tech)
        names = {pair: token for token, pairs in sorted(by_token.items())
                 for pair in pairs}
        shown = [f"{names.get(p, '?')}({p[0]}/{p[1]})"
                 for p in sorted(selected)]
        info(f"[INFO] Rendering {len(selected)} layers: {', '.join(shown)}")

    # Only the selected layers are drawn. Selected layers are also marked
    # valid: some .lyp files carry reserved entries as invalid, which
    # would otherwise stay blank even when selected.
    for lyp in view.each_layer():
        pair = (lyp.source_layer, lyp.source_datatype)
        lyp.visible = lyp.source_layer >= 0 and pair in selected
        if lyp.visible:
            lyp.valid = True

    cellview = view.active_cellview()
    layout = cellview.layout()
    cell = resolve_cell(layout, args.layout, args.cell)
    cellview.cell = cell
    view.max_hier()

    bbox = visible_bbox(layout, cell, selected)
    if bbox.empty():
        die(f"Nothing to render: the selected layers hold no shapes in "
            f"cell '{cell.name}'.")
    if args.bbox:
        if not args.bbox.overlaps(bbox):
            die(f"The region {args.bbox} lies outside the drawn geometry "
                f"of cell '{cell.name}' ({bbox}).")
        bbox = args.bbox
    if bbox.width() > 10 ** 5 or bbox.height() > 10 ** 5:
        # No die is 10 cm wide: almost certainly stray shapes, e.g.
        # coordinates wrapped around the 32-bit GDS integer range.
        print(f"[WARNING] The rendered area is huge "
              f"({bbox.width():.0f} x {bbox.height():.0f} um), the "
              f"layout probably contains stray shapes far off the die "
              f"(the image will look empty)!", file=sys.stderr)
    width, height = image_size(bbox, args.width, args.height)
    if width * height * args.oversampling ** 2 > 10 ** 8:
        print(f"[WARNING] Rendering {width}x{height} pixels with "
              f"{args.oversampling}x oversampling, this may need a lot "
              f"of memory!", file=sys.stderr)

    info(f"[INFO] Rendering cell '{cell.name}' of {args.layout} "
         f"({bbox.width():.2f} x {bbox.height():.2f} um, {tech}).")

    files = []
    for background, path in outputs.items():
        view.set_config("background-color", BACKGROUNDS[background])
        # target=bbox crops to the exact bounding box of the selected
        # layers, so the image has no border margin.
        try:
            view.save_image_with_options(
                path, width, height,
                oversampling=args.oversampling, target=bbox)
        except Exception as e:  # KLayout raises a plain RuntimeError here
            die(f"Cannot write {path}: {e}")
        info(f"[INFO] Written {path} ({width}x{height} pixels, "
             f"{background} background).")
        files.append({"path": path, "background": background,
                      "width_px": width, "height_px": height})

    if args.json:
        # With both dimensions given the geometry is fitted inside, so the
        # larger of the two scales is the one that holds.
        um_per_px = max(bbox.width() / width, bbox.height() / height)
        sak_json.emit(
            TOOL, "ok", [sak_json.input_entry(args.layout)],
            {"bbox_um": [round(v, 6) for v in
                         (bbox.left, bbox.bottom, bbox.right, bbox.top)],
             "um_per_px": round(um_per_px, 6), "files": files},
            True, "")
    info("[DONE] Bye!")
    sys.exit(ERR_NONE)


def run():
    """Call main(), reporting an unexpected exception through die() with --json."""
    try:
        main()
    except Exception as e:  # pylint: disable=broad-except
        if not JSON_MODE:
            raise
        die(f"unexpected {type(e).__name__}: {e}")


if __name__ == "__main__":
    run()
