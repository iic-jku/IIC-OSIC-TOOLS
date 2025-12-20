#!/bin/bash
set -e

echo "[INFO] Install EDA packages via APT"
apt install -y \
	python3-gmsh \
	gmsh \
	gnuplot \
	gnuplot-x11

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	amaranth[builtin-yosys]==0.5.6 \
	cace==2.9.0 \
	ciel==2.4.0 \
	cocotb==2.0.1 \
	edalize==0.6.3 \
	fault-dft==0.9.4 \
	fusesoc==2.4.5 \
	gdsfactory==9.25.2 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.7 \
	lctime==0.0.26 \
	librelane==2.4.10 \
	najaeda==0.3.0 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	schemdraw[svgmath]==0.21 \
	scikit-rf==1.9.0 \
	siliconcompiler==0.35.4 \
	spicelib==1.4.7 \
	spyci==1.0.2

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
#echo "[INFO] Installing dev version of LibreLane"
#pip install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
#	https://github.com/librelane/librelane/tarball/dev

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl \
	rggen-veryl
