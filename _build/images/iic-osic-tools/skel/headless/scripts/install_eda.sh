#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Unlike the base install, no --ignore-installed here: (1) it would re-install
# every dependency already provided by the base image (scipy, pandas, ...) as
# a shadow copy in this layer, growing the image by several 100 MB; (2) pip
# must honour the APT-provided python3-gmsh as satisfying the gmsh
# dependency of gds2palace/setupEM — upstream gmsh ships no
# Linux-aarch64 wheel, so a forced PyPI reinstall would fail on arm64
PIP_FLAGS="--upgrade --no-cache-dir --break-system-packages"

# Nothing below reads PIP_NO_CACHE_DIR -- pip itself does: every pip option has
# a PIP_<OPTION> environment variable equivalent, so this is the same as adding
# --no-cache-dir to every pip run, including ones this script never spells out.
#
# That is the point, because the flag in PIP_FLAGS only covers the outer pip.
# It is not always handed down to the nested pip that PEP 517 build isolation
# runs to fetch a package's build dependencies. The venvs below are the clearest
# case: "python3 -m venv" bootstraps the pip bundled with CPython (24.0), which
# does not forward the flag, so building the git+ packages pulls setuptools,
# virtualenv, distlib, dulwich, numpy, ... straight into $HOME/.cache/pip. With
# HOME=/headless during the build that left ~55 MB of download residue in the
# image. An environment variable IS inherited by those nested invocations.
export PIP_NO_CACHE_DIR=1

echo "[INFO] Install EDA packages via APT"
apt-get update
apt-get install -y \
	gnuplot \
	gnuplot-x11 \
	libqhull-dev \
	potrace \
	python3-dev \
	python3-gmsh

echo "[INFO] Install EDA packages via PIP"

# Without --ignore-installed, pip must UNINSTALL a package when an EDA
# dependency needs a newer version than the visible one — and that fails for
# Debian-installed packages ("RECORD file not found"). Shadow-install those
# packages first: --ignore-installed puts a pip-managed copy into /usr/local
# that hides the Debian one, and the main install below can then upgrade it
# cleanly. Currently only blinker (Debian 1.7.0, Flask needs >=1.9); add
# further packages here if a build fails with "Cannot uninstall X ...
# installed by debian".
pip3 install $PIP_FLAGS --ignore-installed \
	blinker

# amaranth deliberately without [builtin-yosys]: that extra pulls in the
# WASM-based amaranth-yosys + wasmtime (~75 MB); amaranth uses the native
# yosys from PATH instead
pip3 install $PIP_FLAGS \
	"amaranth==0.5.9" \
	cace==2.11.0 \
	chipify==0.2.2 \
	ciel==2.6.1 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.8 \
	fault-dft==0.9.4 \
	fusesoc==2.4.6 \
	gds2palace==0.3.2 \
	gdsfactory==9.47.0 \
	gdsfill==0.1.8 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.12 \
	klayout-vector-file-export-cli==0.5 \
	lctime==0.0.26 \
	librelane==3.1.0.dev2 \
	najaeda==0.7.19 \
	pygmid==1.2.12 \
	pyrtl==1.0.2 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.23" \
	scikit-rf==2.0.1 \
	setupEM==0.2.2 \
	siliconcompiler==0.38.2 \
	snp2le==0.1.7 \
	spicelib==1.6.3 \
	spyci==1.0.2

# The four packages pulling in PySide6 (chipify, snp2le, gds2palace, setupEM)
# only use QtWidgets/QtCore/QtGui/QtSvg, all of which live in
# PySide6-Essentials. The PySide6-Addons half (~340 MB, dominated by a 254 MB
# embedded Chromium in QtWebEngine, plus Qt3D/Quick3D/Designer/Multimedia) is
# not imported by anything in the image, so remove it.
#
# Catch: the Essentials and Addons wheels BOTH ship the shared top-level PySide6
# files (PySide6/__init__.py, _config.py, __feature__.py, _git_pyside_version.py),
# and pip does no cross-package refcounting -- so "pip uninstall PySide6-Addons"
# also deletes the PySide6/__init__.py that Essentials still needs. That leaves
# PySide6 importable only as a namespace package with no __version__, which breaks
# matplotlib's Qt backend ("cannot import name '__version__' from 'PySide6'") and
# every GUI built on it. So force-reinstall Essentials afterwards to rewrite the
# shared files (--no-deps stops Addons from being pulled back in).
#
# The PySide6 meta-package is kept on purpose: gds2palace and setupEM depend on it
# by name, so removing it would leave their dependency unsatisfied. pip check will
# note the meta-package wants Addons, which is harmless at runtime.
echo "[INFO] Removing unused PySide6-Addons (QtWebEngine, Qt3D, ...)"
# Pin the reinstall to the version already resolved above, so it cannot pull a
# newer PySide6-Essentials that mismatches the installed shiboken6.
PYSIDE6_VER=$(pip3 show PySide6-Essentials | awk '/^Version:/{print $2}')
[ -n "$PYSIDE6_VER" ] || { echo "[ERROR] PySide6-Essentials not installed"; exit 1; }
pip3 uninstall -y --break-system-packages PySide6-Addons
pip3 install $PIP_FLAGS --no-deps --force-reinstall "PySide6-Essentials==${PYSIDE6_VER}"

# What is left of PySide6 is still the largest Qt stack in the image, several
# times the size of the system Qt6 that the C++ tools share. Two directories of
# it are dead weight here:
#   Qt/translations (~59 MB) -- Qt's own UI translations, loaded only when an
#     application installs a QTranslator from that path; the image is English.
#   Qt/qml (~35 MB) -- QML module plugins for QtQuick. Every Qt GUI in the
#     image is widget-based, nothing loads a QML engine.
# The .so libraries are untouched, so imports keep working.
echo "[INFO] Pruning PySide6 translations and QML modules"
PYSIDE6_DIR=$(python3 -c 'import os, PySide6; print(os.path.dirname(PySide6.__file__))')
rm -rf "${PYSIDE6_DIR}/Qt/translations" "${PYSIDE6_DIR}/Qt/qml"

echo "[INFO] Install EDA packages via Cargo"

export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

cargo install \
	gdsfill --version 0.1.8 \
	--root "${TOOLS}"

# Drop the Rust toolchain and registry cache so they don't bloat the image.
rm -rf "$RUSTUP_HOME" "$CARGO_HOME"

# The venvs use --system-site-packages so large dependencies already in the
# system Python (numpy, scipy, pandas, ...) are not duplicated inside them;
# only packages with conflicting pins get venv-local copies
echo "[INFO] Installing CharLib"
python3 -m venv --system-site-packages /foss/tools/charlib
/foss/tools/charlib/bin/pip install --no-cache-dir \
	git+https://github.com/stineje/charlib

echo "[INFO] Installing Hdl21/vlsirtools"
python3 -m venv --system-site-packages /foss/tools/vlsirtools
/foss/tools/vlsirtools/bin/pip install --no-cache-dir \
	git+https://github.com/dan-fritchman/Hdl21

# Setup Qucs-S for IHP SG13G2
echo "[INFO] Setting up Qucs-S for IHP SG13G2"
python3 "$PDK_ROOT"/ihp-sg13g2/libs.tech/qucs-s/install.py --no-model-compile --no-qucs-check

# Setup .vacaskrc.toml for IHP SG13G2
echo "[INFO] Setting up VacasK for IHP SG13G2"
cp "$PDK_ROOT"/ihp-sg13g2/libs.tech/vacask/.vacaskrc.toml /headless

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen:0.36.1 \
	rggen-verilog:0.14.0 \
	rggen-vhdl:0.13.0 \
	rggen-veryl:0.8.0

echo "[INFO] EDA package installation completed"

echo "[INFO] Removing build dependencies"
apt-get purge -y libqhull-dev python3-dev
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*

echo "[INFO] Removing bundled Python package test suites"
find /usr/local/lib/python3*/dist-packages \
	/foss/tools/charlib/lib /foss/tools/vlsirtools/lib \
	-type d \( -name tests -o -name test \) -prune -exec rm -rf {} +

# Belt and braces: PIP_NO_CACHE_DIR above should keep this empty, but a tool
# invoking pip with its own environment could still populate it, and the cache
# is pure build residue that must not reach the image. HOME is /headless for
# the whole build, so that is the only cache pip can write.
echo "[INFO] Removing pip download cache"
rm -rf "${HOME:-/headless}/.cache/pip"
