#!/bin/bash

set -e

echo "[INFO] Install Jupyter packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	jupyter \
	jupyterlab \
	jupyter-collaboration \
	jupyterlab-night

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	amaranth==0.5.4 \
	cace==2.5.6 \
	cocotb==1.9.2 \
	edalize==0.6.0 \
	fusesoc==2.4.2 \
	gdsfactory==8.31.2 \
	gdspy==1.6.13 \
	lctime==0.0.24 \
	openlane==2.3.3 \
	openram==1.2.48 \
	pygmid==1.2.12 \
	pyrtl==0.11.2 \
	pyspice==1.5 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.19 \
	scikit-rf==1.5.0 \
	siliconcompiler==0.29.3 \
	spyci==1.0.2 \
	volare==0.20.6


echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl
