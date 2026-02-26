#!/bin/bash
set -e

echo "[INFO] Install EDA packages via APT"
apt install -y \
	gnuplot \
	gnuplot-x11

echo "[INFO] Install EDA packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	"amaranth[builtin-yosys]==0.5.6" \
	cace==2.9.0 \
	ciel==2.4.0 \
	cocotb==2.0.1 \
	edalize==0.6.5 \
	fault-dft==0.9.4 \
	fusesoc==2.4.5 \
	gdsfactory==9.35.2 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.9 \
	lctime==0.0.26 \
	librelane==2.4.13 \
	najaeda==0.4.1 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.21" \
	scikit-rf==1.10.0 \
	siliconcompiler==0.37.0 \
	spicelib==1.4.9 \
	spyci==1.0.2

#FIXME There are currently issues with gmsh for arm64 Linux, so only install for x86_64
if [ "$(arch)" = "x86_64" ]; then
	pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
		gds2palace==0.1.19 \
		gmsh==4.15.1 \
		setupEM==0.1.22
fi

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
