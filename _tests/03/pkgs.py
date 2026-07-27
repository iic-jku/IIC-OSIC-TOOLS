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
import gdsfill
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
import snp2le.app  # noqa: E402,F401
