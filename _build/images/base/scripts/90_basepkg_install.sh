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
	amaranth[builtin-yosys]==0.5.6 \
	cace==2.8.1 \
	ciel==2.0.3 \
	cocotb==1.9.2 \
	edalize==0.6.1 \
	fault-dft==0.9.4 \
	fusesoc==2.4.3 \
	gdsfactory==9.9.4 \
	gdspy==1.6.13 \
	lctime==0.0.25 \
	najaeda==0.1.22 \
	pygmid==1.2.12 \
	pyrtl==0.11.3 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.20 \
	scikit-rf==1.8.0 \
	siliconcompiler==0.34.0 \
	spicelib==1.4.4 \
	spyci==1.0.2

#FIXME	klayout-pex==0.2.7 \

echo "[INFO] Install custom OpenLane2 version"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	git+https://github.com/iic-jku/openlane2

echo "[INFO] Installing CharLib"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	git+https://github.com/stineje/charlib

#FIXME OpenRAM is removed for now, waiting for a release via PyPi
#echo "[INFO] Installing OpenRAM"
#pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
#	git+https://github.com/VLSIDA/OpenRAM

echo "[INFO] Installing Hdl21/vlsirtools"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	git+https://github.com/dan-fritchman/Hdl21

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl \
	rggen-veryl
