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
	python3-dev \
	python3-gmsh

echo "[INFO] Install EDA packages via PIP"
pip3 install $PIP_FLAGS \
	"amaranth[builtin-yosys]==0.5.9" \
	cace==2.11.0 \
	ciel==2.6.1 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.8 \
	fault-dft==0.9.4 \
	fusesoc==2.4.6 \
	gdsfactory==9.45.0 \
	gdsfill==0.1.8 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.12 \
	klayout-vector-file-export-cli==0.5 \
	lctime==0.0.26 \
	librelane==3.1.0.dev1 \
	najaeda==0.7.16 \
	pygmid==1.2.12 \
	pyrtl==1.0.0 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.23" \
	scikit-rf==2.0.1 \
	siliconcompiler==0.38.2 \
	snp2le==0.1.4 \
	spicelib==1.6.2 \
	spyci==1.0.2

# gds2palace and setupEM depend on gmsh, which upstream ships no Linux-aarch64
# wheel/SDK for. gmsh is instead provided for both architectures via the
# python3-gmsh APT package installed above (/usr/lib/python3/dist-packages).
# Install these two here WITHOUT --ignore-installed so pip honours the
# APT-provided gmsh as satisfying the dependency (the main block's --ignore-installed
# would otherwise force a PyPI gmsh reinstall that fails on arm64).
echo "[INFO] Install gmsh-dependent EDA packages via PIP"
pip3 install --no-cache-dir --break-system-packages \
	gds2palace==0.2.0 \
	setupEM==0.1.22

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

echo "[INFO] Installing CharLib"
python3 -m venv /foss/tools/charlib
/foss/tools/charlib/bin/pip install --no-cache-dir \
	git+https://github.com/stineje/charlib

echo "[INFO] Installing Hdl21/vlsirtools"
python3 -m venv /foss/tools/vlsirtools
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
