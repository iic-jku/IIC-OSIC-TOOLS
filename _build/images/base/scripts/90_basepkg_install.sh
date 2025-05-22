#!/bin/bash

set -e

echo "[INFO] Install Jupyter packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	jupyter \
	jupyter-collaboration \
	jupyterlab \
	jupyterlab-night

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	amaranth==0.5.6 \
	cace==2.5.6 \
	cocotb==1.9.2 \
	edalize==0.6.1 \
	fusesoc==2.4.3 \
	gdsfactory==9.5.11 \
	gdspy==1.6.13 \
	lctime==0.0.24 \
	klayout-pex==0.2.5 \
	openram==1.2.48 \
	pygmid==1.2.12 \
	pyrtl==0.11.2 \
	pyspice==1.5 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.20 \
	scikit-rf==1.7.0 \
	siliconcompiler==0.32.3 \
	spicelib==1.4.4 \
	spyci==1.0.2 \
	volare==0.20.6

#FIXME	hdl21==7.0.0 \
#FIXME	vlsirtools==7.0.0 \
#FIXME	librelane==2.4.0.dev0 \
#FIXME	ciel==2.0.2 \
#FIXME	openlane==2.3.10 \ 

echo "[INFO] Install custom OpenLane2 version"
cd /tmp
git clone https://github.com/iic-jku/openlane2.git openlane2
cd openlane2
pip3 install --upgrade --no-cache-dir --break-system-packages .

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl
