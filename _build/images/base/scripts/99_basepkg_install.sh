#!/bin/bash

set -e

echo "[INFO] Install Jupyter packages via PIP"
pip3 install --upgrade --no-cache-dir \
	jupyter \
	jupyterlab \
	jupyter-collaboration \
	jupyterlab-night

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir \
	amaranth==0.5.1 \
	cace==2.3.11 \
	cocotb==1.9.0 \
	edalize==0.5.4 \
	fusesoc==2.3 \
	gdsfactory==8.6.1 \
	gdspy==1.6.13 \
	hdl21==6.0.0 \
	openlane==2.1.0 \
	openram==1.2.48 \
	pygmid==1.2.12 \
	pyrtl==0.11.2 \
	pyspice==1.5 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.19 \
	scikit-rf==1.1.0 \
	siliconcompiler==0.25.0 \
	spyci==1.0.2 \
	vlsirtools==6.0.0 \
	volare==0.18.1

#FIXME OpenLane2 goes last to get its dependencies right
#pip3 install --upgrade --no-cache-dir \
#	openlane==2.0.11
#FIXME Locally build OpenLane2 due to klayout incompatibility
#FIXME Need to add OL2 first, otherwise dependency issue on antlr4-python3-runtime
#cd /tmp
#git clone --depth=1 https://github.com/iic-jku/openlane2.git
#cd openlane2
#pip3 install .
#cd /


echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl

