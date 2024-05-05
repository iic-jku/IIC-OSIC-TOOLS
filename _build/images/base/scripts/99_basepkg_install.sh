#!/bin/bash

set -e

#FIXME pinning gdsfactory to 7.10, as otherwise build of gdstks fails on aarch64 (such adding gdstk as well)

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages \
	amaranth \
	cace \
	cocotb \
	edalize \
	fusesoc \
	gdsfactory==7.10 \
	gdstk==0.9.40 \
	gdspy \
	openlane==2.0.3 \
	openram \
	pyrtl \
	pyspice \
	pyverilog \
	schemdraw \
	scikit-rf \
	siliconcompiler \
	spyci \
	volare

#FIXME: temporary remove hdl21 and vlsirtools

pip3 install --upgrade --no-cache-dir --break-system-packages \
	jupyter \
	jupyterlab \
	jupyter-collaboration \
	jupyterlab-night


echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl

echo "[INFO] Install EDA packages via NPM"
npm install -g \
	netlistsvg
