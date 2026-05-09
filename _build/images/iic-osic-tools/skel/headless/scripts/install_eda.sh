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
	ciel==2.4.1 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.8 \
	fault-dft==0.9.4 \
	fusesoc==2.4.5 \
	gdsfactory==9.41.0 \
	gdsfill==0.1.5 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.12 \
	klayout-vector-file-export-cli==0.5 \
	lctime==0.0.26 \
	librelane==3.0.3 \
	najaeda==0.6.2 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.22" \
	scikit-rf==1.12.0 \
	siliconcompiler==0.37.9 \
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

# Create dedicated gdsfactory venvs for KLayout pcell compatibility.

echo "[INFO] Creating gdsfactory8 venv for KLayout sky130A/B pcell compatibility"
python3 -m venv /foss/tools/klayout_gdsfactory8
/foss/tools/klayout_gdsfactory8/bin/pip install --no-cache-dir "gdsfactory==8.0.0"

echo "[INFO] Creating gdsfactory9 venv for KLayout gf180mcuC/D pcell compatibility"
python3 -m venv /foss/tools/klayout_gdsfactory9
/foss/tools/klayout_gdsfactory9/bin/pip install --no-cache-dir "gdsfactory==9.20.6"

echo "[INFO] EDA package installation completed"

echo "[INFO] Removing build dependencies"
apt-get purge -y libqhull-dev python3-dev
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
