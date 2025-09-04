#!/bin/bash
set -e

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	amaranth[builtin-yosys]==0.5.6 \
	cace==2.8.3 \
	ciel==2.1.4 \
	cocotb==1.9.2 \
	edalize==0.6.1 \
	fault-dft==0.9.4 \
	fusesoc==2.4.3 \
	gdsfactory==9.14.0 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.2 \
	lctime==0.0.26 \
	librelane==2.4.1 \
	najaeda==0.2.10 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==3.0.0 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.20 \
	scikit-rf==1.8.0 \
	siliconcompiler==0.34.3 \
	spicelib==1.4.5 \
	spyci==1.0.2

#echo "[INFO] Install custom OpenLane2 version"
#pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
#	git+https://github.com/iic-jku/openlane2

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
