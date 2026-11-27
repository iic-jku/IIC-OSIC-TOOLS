#!/usr/bin/env python3
# ========================================================================
# Layer names and metal stacks of the supported PDKs for the sak helper commands
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
# Imported by the sak-*.py helpers (not a command itself).
# ========================================================================

"""Layer names of a PDK, read from its KLayout layer properties file, and the metal stacks of the PDKs."""

import os
import re
import xml.etree.ElementTree as ET

# PDK name -> path of the .lyp file below $PDK_ROOT. The same files as the TECHS table of sak-render.py.
LYP_FILES = {
    "ihp-sg13g2": ("ihp-sg13g2", "libs.tech", "klayout", "tech", "sg13g2.lyp"),
    "ihp-sg13cmos5l": ("ihp-sg13cmos5l", "libs.tech", "klayout", "tech", "sg13cmos5l.lyp"),
    "gf180mcud": ("gf180mcuD", "libs.tech", "klayout", "tech", "gf180mcu.lyp"),
    "sky130a": ("sky130A", "libs.tech", "klayout", "tech", "sky130A.lyp"),
    "asap7": ("asap7", "libs.tech", "klayout", "tech", "asap7.lyp"),
}

ALIASES = {
    "sg13g2": "ihp-sg13g2",
    "sg13cmos5l": "ihp-sg13cmos5l",
    "cmos5l": "ihp-sg13cmos5l",
    "gf180mcu": "gf180mcud",
    "gf180": "gf180mcud",
    "sky130": "sky130a",
    "asap7sc7p5t": "asap7",
}

# The source of a .lyp entry is "[name ]layer/datatype@view"
SOURCE_RE = re.compile(r"^(?:(?P<name>.*\S)\s+)?(?P<layer>\d+)/(?P<datatype>\d+)(?:@.*)?$")


def tech_key(pdk: str) -> str | None:
    """The key of LYP_FILES for a PDK name or alias, None if the PDK is unknown."""
    key = re.sub(r"[-_.\s]", "", (pdk or "").lower())
    keys = {re.sub(r"[-_.\s]", "", k): k for k in LYP_FILES}
    keys.update({re.sub(r"[-_.\s]", "", a): t for a, t in ALIASES.items()})
    return keys.get(key)


def layer_names(pdk: str, pdk_root: str) -> dict[tuple[int, int], str]:
    """Map (layer, datatype) to the layer name of the PDK's .lyp file.

    The name is the part before ``" - "``, as ``lyp_names_of()`` of sak-render.py takes it (IHP names its entries
    ``Metal1.drawing``, sky130A appends the numbers). gf180mcu leaves the name empty and carries the name in the
    source specification instead. An unknown PDK or a missing or unreadable file gives an empty dict.
    """
    tech = tech_key(pdk)
    if tech is None:
        return {}
    path = os.path.join(pdk_root, *LYP_FILES[tech])
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError):
        return {}
    names: dict[tuple[int, int], str] = {}
    for entry in root.iter("properties"):
        match = SOURCE_RE.match((entry.findtext("source") or "").strip())
        if not match:
            continue  # group entries carry a wildcard source
        name = (entry.findtext("name") or "").split(" - ")[0].strip() or (match.group("name") or "")
        if name:
            names.setdefault((int(match.group("layer")), int(match.group("datatype"))), name)
    return names


# Metal stacks for sak_netgraph.py: the conductors and cuts as the KLayout LVS deck of the PDK derives them (drawing
# plus filler, minus slit, minus device bodies), the per-cut rules for the room test and the DC current limits.
# Lengths in um, currents in mA (time-averaged DC), resistances in Ohm.
#
# Conductor keys: layers (joined), minus (subtracted), body (device bodies cut out of the conductor, a polygon that
# touches one is a device terminal), terminal ("all": every polygon is a device terminal), terminal_with (a polygon
# that interacts with these layers is a device terminal), pin and label (pin shapes and net labels), rs (sheet
# resistance in Ohm/sq, None keeps the conductor out of the resistive solve), min_width, limit (flat_ma up to
# flat_um wide, ma_per_um x width above, None if the PDK publishes no limit).
# Cut keys: layers (joined), and_layers (intersected), minus, lower (conductor names), upper, r (Ohm per cut),
# imax (mA per cut), size, space, enc_lower and enc_upper as (all sides, endcap on two opposite sides).

_IHP_LIMIT_M1 = {"flat_ma": 0.36, "flat_um": 0.36, "ma_per_um": 1.0}
_IHP_LIMIT_MN = {"flat_ma": 0.6, "flat_um": 0.3, "ma_per_um": 2.0}


def _ihp_metal(name: str, layer: int, rs: float, min_width: float, limit: dict | None, body: tuple = (),
               terminal_with: tuple = ()) -> dict:
    """An IHP metal: drawing plus filler minus slit, its resistor marker (datatype 29) as device body."""
    return {"name": name, "layers": [(layer, 0), (layer, 22)], "minus": [(layer, 24)],
            "body": [(layer, 29), *body], "terminal_with": list(terminal_with), "pin": (layer, 2),
            "label": (layer, 25), "rs": rs, "min_width": min_width, "limit": limit}


def _ihp_cut(name: str, layer: int, lower: str, upper: str, r: float, imax: float, size: float, space: float,
             enc_lower: tuple, enc_upper: tuple, minus: tuple = ()) -> dict:
    """An IHP via layer between two conductors."""
    return {"name": name, "layers": [(layer, 0)], "and_layers": [], "minus": list(minus), "lower": [lower],
            "upper": upper, "r": r, "imax": imax, "size": size, "space": space, "enc_lower": enc_lower,
            "enc_upper": enc_upper}


# Activ minus GatPoly gives the source/drain and tap regions, GatPoly minus the resistor markers the gates and the
# resistor heads (general_derivations.lvs). The process specification gives no limit for either conductor, and the
# resistor bodies, which have one, are devices and not checked here.
_IHP_FEOL = [
    {"name": "Activ", "layers": [(1, 0), (1, 22)], "minus": [(5, 0), (5, 22)], "body": [], "terminal": "all",
     "terminal_with": [], "pin": (1, 2), "label": None, "rs": None, "min_width": 0.15, "limit": None},
    {"name": "GatPoly", "layers": [(5, 0), (5, 22)], "minus": [], "body": [(128, 0), (24, 0)],
     "terminal_with": [(1, 0), (1, 22)], "pin": (5, 2), "label": None, "rs": None, "min_width": 0.13,
     "limit": None},
]
_IHP_MIM = {"name": "MIM", "layers": [(36, 0)], "minus": [], "body": [], "terminal": "all", "terminal_with": [],
            "pin": None, "label": None, "rs": None, "min_width": 1.14, "limit": None}
_IHP_CONT = {"name": "Cont", "layers": [(6, 0)], "and_layers": [], "minus": [], "lower": ["Activ", "GatPoly"],
             "upper": "Metal1", "r": 22.0, "imax": 0.3, "size": 0.16, "space": 0.18, "enc_lower": (0.07, 0.07),
             "enc_upper": (0.0, 0.05)}
# Vmim joins the MIM top plate to TopMetal1, the deck takes TopVia1 over MIM as Vmim too (cap_derivations.lvs)
_IHP_VMIM = {"name": "Vmim", "layers": [(129, 0), (125, 0)], "and_layers": [(36, 0)], "minus": [],
             "lower": ["MIM"], "upper": "TopMetal1", "r": None, "imax": None, "size": None, "space": None,
             "enc_lower": None, "enc_upper": None}
_IHP_VIA_ENC = (0.005, 0.05)  # Mn.c, Mn.c1 and Vn.c, Vn.c1

STACKS = {
    "ihp-sg13g2": {
        "limits_source": "SG13G2 Process Specification Rev. 1.2, section 2.15 (11 years at 105 C)",
        "resistance_source": "sg13g2_tech.lef (RPERSQ and RESISTANCE)",
        "rules_source": "SG13G2 Layout Rules Rev. 0.4",
        "temperature_c": 105,
        "pad": {"layers": [(9, 0)], "conductor": "TopMetal2"},
        "conductors": [
            *_IHP_FEOL,
            _ihp_metal("Metal1", 8, 0.135, 0.16, _IHP_LIMIT_M1),
            _ihp_metal("Metal2", 10, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("Metal3", 30, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("Metal4", 50, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("Metal5", 67, 0.103, 0.20, _IHP_LIMIT_MN, terminal_with=((36, 0),)),
            _ihp_metal("TopMetal1", 126, 0.021, 1.64, {"flat_ma": None, "flat_um": 0.0, "ma_per_um": 15.0},
                       body=((27, 0),)),
            _ihp_metal("TopMetal2", 134, 0.0145, 2.0, {"flat_ma": None, "flat_um": 0.0, "ma_per_um": 16.0},
                       body=((27, 0),)),
            _IHP_MIM,
        ],
        "cuts": [
            _IHP_CONT,
            _ihp_cut("Via1", 19, "Metal1", "Metal2", 20.0, 0.4, 0.19, 0.22, (0.01, 0.05), _IHP_VIA_ENC),
            _ihp_cut("Via2", 29, "Metal2", "Metal3", 20.0, 0.4, 0.19, 0.22, _IHP_VIA_ENC, _IHP_VIA_ENC),
            _ihp_cut("Via3", 49, "Metal3", "Metal4", 20.0, 0.4, 0.19, 0.22, _IHP_VIA_ENC, _IHP_VIA_ENC),
            _ihp_cut("Via4", 66, "Metal4", "Metal5", 20.0, 0.4, 0.19, 0.22, _IHP_VIA_ENC, _IHP_VIA_ENC),
            _ihp_cut("TopVia1", 125, "Metal5", "TopMetal1", 4.0, 1.4, 0.42, 0.42, (0.10, 0.10), (0.42, 0.42),
                     minus=((36, 0),)),
            _ihp_cut("TopVia2", 133, "TopMetal1", "TopMetal2", 2.2, 10.0, 0.90, 1.06, (0.50, 0.50),
                     (0.50, 0.50)),
            _IHP_VMIM,
        ],
    },
    "ihp-sg13cmos5l": {
        "limits_source": "SG13CMOS5L Process Specification Rev. 0.2, section 3.5 (11 years at 105 C)",
        "resistance_source": "sg13cmos5l_tech.lef (RPERSQ and RESISTANCE)",
        "rules_source": "SG13CMOS5L Layout Rules Rev. 0.1",
        "temperature_c": 105,
        "pad": {"layers": [(9, 0)], "conductor": "TopMetal1"},
        "conductors": [
            *_IHP_FEOL,
            _ihp_metal("Metal1", 8, 0.135, 0.16, _IHP_LIMIT_M1),
            _ihp_metal("Metal2", 10, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("Metal3", 30, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("Metal4", 50, 0.103, 0.20, _IHP_LIMIT_MN),
            _ihp_metal("TopMetal1", 126, 0.021, 1.64, {"flat_ma": None, "flat_um": 0.0, "ma_per_um": 15.0},
                       body=((27, 0),)),
            _IHP_MIM,
        ],
        "cuts": [
            _IHP_CONT,
            _ihp_cut("Via1", 19, "Metal1", "Metal2", 20.0, 0.4, 0.19, 0.22, (0.01, 0.05), _IHP_VIA_ENC),
            _ihp_cut("Via2", 29, "Metal2", "Metal3", 20.0, 0.4, 0.19, 0.22, _IHP_VIA_ENC, _IHP_VIA_ENC),
            _ihp_cut("Via3", 49, "Metal3", "Metal4", 20.0, 0.4, 0.19, 0.22, _IHP_VIA_ENC, _IHP_VIA_ENC),
            _ihp_cut("TopVia1", 125, "Metal4", "TopMetal1", 4.0, 1.4, 0.42, 0.42, (0.10, 0.10), (0.42, 0.42),
                     minus=((36, 0),)),
            _IHP_VMIM,
        ],
    },
}


def stack(pdk: str) -> dict | None:
    """The metal stack of a PDK name or alias from STACKS, None if the PDK has none."""
    tech = tech_key(pdk)
    return STACKS.get(tech) if tech else None
