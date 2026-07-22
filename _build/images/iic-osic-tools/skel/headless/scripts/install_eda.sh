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
	chipify==0.2.1 \
	ciel==2.6.1 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.8 \
	fault-dft==0.9.4 \
	fusesoc==2.4.6 \
	gds2palace==0.2.0 \
	gdsfactory==9.46.0 \
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
	setupEM==0.1.22 \
	siliconcompiler==0.38.2 \
	snp2le==0.1.4 \
	spicelib==1.6.3 \
	spyci==1.0.2

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
