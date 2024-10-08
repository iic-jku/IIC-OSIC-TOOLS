#!/bin/bash

set -e

echo "[INFO] Install Jupyter packages via PIP"
pip3 install --upgrade --no-cache-dir \
	jupyter \
	jupyterlab \
	jupyter-collaboration \
	jupyterlab-night

#FIXME gdfsfactory >= 8.8.6 requires Python 3.11
echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir \
	amaranth==0.5.2 \
	cace==2.4.14 \
	cocotb==1.9.1 \
	edalize==0.5.4 \
	fusesoc==2.3 \
	gdsfactory==8.8.2 \
	gdspy==1.6.13 \
	openlane==2.1.4 \
	openram==1.2.48 \
	pygmid==1.2.12 \
	pyrtl==0.11.2 \
	pyspice==1.5 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.19 \
	scikit-rf==1.3.0 \
	siliconcompiler==0.27.1 \
	spyci==1.0.2 \
	volare==0.19.1

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl
