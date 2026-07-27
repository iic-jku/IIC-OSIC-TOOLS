########################################################################
#
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
########################################################################
#
# KLayout PCell smoke/regression harness (driven by test_klayout_pcells.sh).
#
# For the active PDK (taken from $PDK) this script:
#   - discovers every PCell library the PDK registers in KLayout (skipping
#     KLayout's built-in "Basic"/"DEFAULT" libraries),
#   - instantiates every PCell once with its declared default parameters,
#   - classifies the result as OK / EMPTY / ERROR:
#       OK    - the cell (incl. its hierarchy) contains at least one shape
#       EMPTY - instantiation succeeded but produced no geometry at all
#       ERROR - create_cell raised a Python exception
#   - compares the outcome against the per-PDK baseline in EXPECTED below and
#     exits non-zero on any deviation (a good PCell breaking, a known-bad one
#     changing verdict, or the PCell inventory drifting).
#
# Run standalone (bash syntax) after `source sak-pdk-script.sh <pdk>`:
#   cd <writable-dir> && klayout -zz -r check_pcells.py
# A writable current directory is required: the gdsfactory-based sky130A and
# gf180mcuD PCells write a temporary GDS into the CWD while producing geometry.
#
########################################################################

import os
import sys

import pya

# KLayout ships these libraries itself; they are not part of any PDK.
BUILTIN_LIBS = {"Basic", "DEFAULT"}

# Per-PDK baseline. "count" is the total number of PCells the PDK is expected
# to register across all its libraries. "known_bad" pins PCells that do NOT
# produce geometry with their default parameters, so the test stays green on
# the current image while still catching regressions. Keys are "<library>/
# <pcell>" because the same PCell name can appear in several libraries of one
# PDK with different verdicts (gf180mcuD ships diode_dw2ps in both gf180mcu and
# gf180mcu_klayoutapi, and only the latter is broken). See README.md for why
# each entry is here. Tighten this list once the upstream PDK is fixed.
EXPECTED = {
    "sky130A": {
        "count": 18,
        "known_bad": {},
    },
    "gf180mcuD": {
        "count": 61,
        # The gf180mcu_klayoutapi library (and gf180mcu_sealring) came in with
        # the KLayout-API device generators; the classic gf180mcu library still
        # ships the same devices and produces them correctly.
        #
        # diode_dw2ps, diode_pw2dw: their generator recurses in Cell.flatten
        #   (libs.tech/klayout/tech/pymacros/klayout_api_cells/draw_diode.py)
        #   and allocates until it dies with std::bad_alloc -- 95 s and >6 GB
        #   for diode_dw2ps alone. Without the address-space cap that
        #   test_klayout_pcells.sh puts around KLayout, it grows past 15 GB and
        #   the kernel OOM-kills the whole run.
        # efuse: draw_efuse() is called without its required device_name
        #   argument and raises TypeError.
        "known_bad": {
            "gf180mcu_klayoutapi/diode_dw2ps": "empty",
            "gf180mcu_klayoutapi/diode_pw2dw": "empty",
            "gf180mcu_klayoutapi/efuse": "empty",
        },
    },
    "ihp-sg13g2": {
        "count": 34,
        "known_bad": {},
    },
    "ihp-sg13cmos5l": {
        "count": 24,
        "known_bad": {},
    },
}


def pdk_libraries():
    """Yield (lib_name, tech_name, library) for every non-builtin PCell library.

    Some PDKs (the IHP ones) register their library against a specific
    technology, so library_by_name() must be queried with that technology to
    get a usable layout; others register globally (technology ""). We probe the
    known technologies plus the global scope and take the first that resolves.
    """
    techs = [None] + list(pya.Technology.technology_names())
    for name in sorted(pya.Library.library_names()):
        if name in BUILTIN_LIBS:
            continue
        for tech in techs:
            lib = (
                pya.Library.library_by_name(name, tech)
                if tech
                else pya.Library.library_by_name(name)
            )
            if lib is not None and lib.layout() is not None:
                yield name, tech, lib
                break


def count_shapes(cell, layout):
    """Total number of shapes in a cell and its whole instance hierarchy."""
    n = 0
    for layer_index in layout.layer_indexes():
        n += cell.shapes(layer_index).size()
    for inst in cell.each_inst():
        n += count_shapes(inst.cell, layout)
    return n


def classify_pcell(lib_name, tech, lib, pcell_name):
    """Instantiate one PCell with default parameters and classify the result."""
    liblayout = lib.layout()
    decl = liblayout.pcell_declaration(pcell_name)
    params = {p.name: p.default for p in decl.get_parameters()}

    top = pya.Layout()
    if tech:
        top.technology_name = tech
    try:
        cell = top.create_cell(pcell_name, lib_name, params)
        if cell is None:
            return "error", "create_cell returned None"
        n = count_shapes(cell, top)
        if n == 0:
            return "empty", "no geometry produced"
        return "ok", "%d shapes" % n
    except Exception as exc:  # noqa: BLE001 - report any PCell produce failure
        return "error", "%s: %s" % (type(exc).__name__, exc)
    finally:
        top._destroy()


def main():
    pdk = os.environ.get("PDK", "")
    if pdk not in EXPECTED:
        print("[HARNESS] Unknown or unset PDK %r (set via sak-pdk-script.sh)" % pdk)
        return 2

    baseline = EXPECTED[pdk]
    known_bad = dict(baseline["known_bad"])

    results = []  # (lib_name, pcell_name, status, detail)
    for lib_name, tech, lib in pdk_libraries():
        for pcell_name in lib.layout().pcell_names():
            status, detail = classify_pcell(lib_name, tech, lib, pcell_name)
            results.append((lib_name, pcell_name, status, detail))

    n_ok = sum(1 for r in results if r[2] == "ok")
    n_empty = sum(1 for r in results if r[2] == "empty")
    n_error = sum(1 for r in results if r[2] == "error")

    print("[HARNESS] PDK %s: %d PCells (ok=%d empty=%d error=%d)"
          % (pdk, len(results), n_ok, n_empty, n_error))
    for lib_name, pcell_name, status, detail in results:
        print("  %-6s %s/%s (%s)" % (status.upper(), lib_name, pcell_name, detail))

    # ---- compare against the baseline -------------------------------------
    deviations = []

    if len(results) != baseline["count"]:
        deviations.append(
            "PCell inventory changed: found %d, expected %d "
            "(a PCell was added or removed)" % (len(results), baseline["count"])
        )

    for lib_name, pcell_name, status, detail in results:
        expected = known_bad.pop("%s/%s" % (lib_name, pcell_name), "ok")
        if status != expected:
            if expected == "ok":
                deviations.append(
                    "REGRESSION %s/%s is now %s (%s), expected OK"
                    % (lib_name, pcell_name, status.upper(), detail)
                )
            else:
                deviations.append(
                    "BASELINE CHANGED %s/%s is now %s (%s), baseline pins it as %s "
                    "- if fixed upstream, drop it from known_bad"
                    % (lib_name, pcell_name, status.upper(), detail, expected.upper())
                )

    # any known-bad PCell we never saw has disappeared or been renamed
    for qualified_name, expected in known_bad.items():
        deviations.append(
            "MISSING known-bad PCell %r (baseline pins it as %s) was not found"
            % (qualified_name, expected.upper())
        )

    if deviations:
        print("[HARNESS] VERDICT FAIL for %s:" % pdk)
        for d in deviations:
            print("  - " + d)
        return 1

    print("[HARNESS] VERDICT PASS for %s (%d OK, %d expected-empty pinned)"
          % (pdk, n_ok, n_empty + n_error))
    return 0


if __name__ == "__main__":
    sys.exit(main())
