# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

# We just import a few of the heavy Python packages and see if there
# is an error or warning thrown.

import amaranth
import cace
import chipify
import ciel
import cocotb
import edalize
import fusesoc
import gdsfactory
import gdspy
import najaeda
import librelane
import pygmid
import PySpice
import skrf
import siliconcompiler
import spicelib
import spyci

# The Qt GUIs (chipify, snp2le) reach matplotlib's qtagg backend, which needs
# PySide6.__version__ from PySide6/__init__.py. That file is shared between
# PySide6-Essentials, PySide6-Addons and the PySide6 meta-package, and the
# image uninstalls Addons -- so check it and import the GUI entry points to
# catch a PySide6 installation that got gutted by that uninstall.
import PySide6

assert PySide6.__version__, "PySide6/__init__.py missing (PySide6-Addons uninstall?)"

import chipify.gui_qt.app  # noqa: E402,F401
import prep_ic.gui.app  # noqa: E402,F401
import snp2le.app  # noqa: E402,F401

# Discover and load every shipped exporter through KPEX, so an installed wheel
# with a missing entry point or incompatible plugin API fails this image test.
from klayout_pex.pex25d.exporters import exporter_registry

registry = exporter_registry()
for name in ("elmer", "gmsh", "kqcircuits", "palace"):
    provider = f"klayout-pex-plugin-{name}"
    matching = [info for info in registry.exporters
                if info.name == name and info.distribution == provider]
    assert len(matching) == 1, f"Expected one {provider} exporter, got {matching}"
    exporter = registry.load(matching[0].qualified_name)
    assert callable(exporter.export), f"{provider} has no export method"
