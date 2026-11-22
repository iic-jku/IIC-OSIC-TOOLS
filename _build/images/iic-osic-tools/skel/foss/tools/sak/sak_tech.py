#!/usr/bin/env python3
# ========================================================================
# Layer names of the supported PDKs for the sak helper commands
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

"""Layer names of a PDK, read from its KLayout layer properties file."""

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


def layer_names(pdk: str, pdk_root: str) -> dict[tuple[int, int], str]:
    """Map (layer, datatype) to the layer name of the PDK's .lyp file.

    The name is the part before ``" - "``, as ``lyp_names_of()`` of sak-render.py takes it (IHP names its entries
    ``Metal1.drawing``, sky130A appends the numbers). gf180mcu leaves the name empty and carries the name in the
    source specification instead. An unknown PDK or a missing or unreadable file gives an empty dict.
    """
    key = re.sub(r"[-_.\s]", "", (pdk or "").lower())
    keys = {re.sub(r"[-_.\s]", "", k): k for k in LYP_FILES}
    keys.update({re.sub(r"[-_.\s]", "", a): t for a, t in ALIASES.items()})
    tech = keys.get(key)
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
