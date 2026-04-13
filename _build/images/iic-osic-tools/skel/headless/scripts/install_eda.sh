#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

PIP_FLAGS="--upgrade --no-cache-dir --break-system-packages --ignore-installed"

echo "[INFO] Install EDA packages via APT"
apt-get update
apt-get install -y \
	gnuplot \
	gnuplot-x11 \
	libqhull-dev \
	potrace \
	python3-dev

echo "[INFO] Install EDA packages via PIP"
pip3 install $PIP_FLAGS \
	"amaranth[builtin-yosys]==0.5.8" \
	cace==2.9.0 \
	ciel==2.4.0 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.6 \
	fault-dft==0.9.4 \
	fusesoc==2.4.5 \
	gdsfactory==9.20.6 \
	gdsfill==0.1.5 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.10 \
	klayout-vector-file-export-cli==0.5 \
	lctime==0.0.26 \
	librelane==3.0.2 \
	najaeda==0.5.4 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.22" \
	scikit-rf==1.11.0 \
	siliconcompiler==0.37.5 \
	spicelib==1.5.1 \
	spyci==1.0.2

#FIXME There are currently issues with gmsh for arm64 Linux, so only install for x86_64
if [ "$(uname -m)" = "x86_64" ]; then
	echo "[INFO] Install x86_64-only EDA packages via PIP"
	pip3 install $PIP_FLAGS \
		gds2palace==0.1.19 \
		gmsh==4.15.2 \
		setupEM==0.1.22
fi

echo "[INFO] Installing CharLib"
python3 -m venv /foss/tools/charlib
/foss/tools/charlib/bin/pip install --no-cache-dir \
	git+https://github.com/stineje/charlib

#FIXME OpenRAM is removed for now, waiting for a release via PyPi
#echo "[INFO] Installing OpenRAM"
#pip3 install $PIP_FLAGS \
#	git+https://github.com/VLSIDA/OpenRAM

echo "[INFO] Installing Hdl21/vlsirtools"
python3 -m venv /foss/tools/vlsirtools
/foss/tools/vlsirtools/bin/pip install --no-cache-dir \
	git+https://github.com/dan-fritchman/Hdl21

#FIXME See https://github.com/librelane/librelane/issues/767
#echo "[INFO] Installing dev version of LibreLane"
#pip3 install $PIP_FLAGS \
#	https://github.com/librelane/librelane/tarball/dev

# Setup Qucs-S for IHP SG13G2
echo "[INFO] Setting up Qucs-S for IHP SG13G2"
python3 "$PDK_ROOT"/ihp-sg13g2/libs.tech/qucs-s/install.py --no-model-compile --no-qucs-check

# Setup .vacaskrc.toml for IHP SG13G2
echo "[INFO] Setting up VacasK for IHP SG13G2"
cp "$PDK_ROOT"/ihp-sg13g2/libs.tech/vacask/.vacaskrc.toml /headless

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl \
	rggen-veryl

# Create dedicated gdsfactory8 venv for KLayout sky130A/B pcell compatibility.
# sky130A/B pcell libraries require gdsfactory==8.0.0 (the version that introduced
# the KLayout/kdb backend with kfactory 0.17.x APIs). The system gdsfactory
# (pinned to 9.20.6 for gf180mcuC/D compatibility) is incompatible with sky130 pcells.
# sak-pdk sets KLAYOUT_PYTHONPATH to this venv's site-packages when switching to
# sky130A/B, so KLayout prepends it to Python sys.path and pcell libraries load correctly.
echo "[INFO] Creating gdsfactory8 venv for KLayout sky130A/B pcell compatibility"
python3 -m venv /foss/tools/klayout_gdsfactory8
/foss/tools/klayout_gdsfactory8/bin/pip install --no-cache-dir "gdsfactory==8.0.0"

# Suppress the (harmless) "in um is deprecated" loguru WARNINGs from gdsfactory 8.0.0.
_GF8_SITE=$(/foss/tools/klayout_gdsfactory8/bin/python3 -c 'import site; print(site.getsitepackages()[0])')
cat > "${_GF8_SITE}/sitecustomize.py" << 'PYEOF'
"""Suppress gdsfactory 8.0.0 attribute-access deprecation warnings in KLayout.

The sky130A pcell code accesses .ymax/.xmax etc. on Component objects, which
triggers "in um is deprecated" WARNINGs from gdsfactory 8 (via loguru). Since we
pin to gdsfactory==8.0.0 where the behavior is still correct (returns um as the
pcell code expects), these warnings are harmless noise. They are suppressed here
so that loguru output from pcell loading remains clean.
"""
import sys as _sys

from loguru import logger as _logger

_logger.remove()
_logger.add(_sys.stderr, filter=lambda r: "in um is deprecated" not in r["message"])
PYEOF
unset _GF8_SITE

echo "[INFO] EDA package installation completed"

echo "[INFO] Removing build dependencies"
apt-get purge -y libqhull-dev python3-dev
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
