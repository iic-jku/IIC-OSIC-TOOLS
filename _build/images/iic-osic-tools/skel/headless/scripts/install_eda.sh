#!/bin/bash
set -e

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	amaranth[builtin-yosys]==0.5.6 \
	cace==2.8.3 \
	ciel==2.2.0 \
	cocotb==2.0.0 \
	edalize==0.6.1 \
	fault-dft==0.9.4 \
	fusesoc==2.4.4 \
	gdsfactory==9.15.0 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.2 \
	lctime==0.0.26 \
	najaeda==0.2.11 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.20 \
	scikit-rf==1.8.0 \
	siliconcompiler==0.34.3 \
	spicelib==1.4.6 \
	spyci==1.0.2

#FIXME Remove pyuvm for now, as it needs cocotb<2
#pyuvm==3.0.0 \

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

#FIXME See https://github.com/librelane/librelane/issues/767
echo "[INFO] Installing dev version of LibreLane"
pip install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	https://github.com/librelane/librelane/tarball/dev

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl \
	rggen-veryl
