#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

PIP_FLAGS="--upgrade --no-cache-dir --break-system-packages --ignore-installed"

echo "[INFO] Install EDA packages via APT"
apt-get update
apt-get install -y \
	gnuplot \
	gnuplot-x11 \
	libqhull-dev \
	potrace \
	python3-dev
rm -rf /var/lib/apt/lists/*

echo "[INFO] Install EDA packages via PIP"
pip3 install $PIP_FLAGS \
	"amaranth[builtin-yosys]==0.5.8" \
	cace==2.9.0 \
	ciel==2.4.0 \
	cocotb==2.0.1 \
	cocotbext-ams==0.1.0 \
	edalize==0.6.6 \
	fault-dft==0.9.4 \
	fusesoc==2.4.5 \
	gdsfactory==9.20.6 \
	gdsfill==0.1.5 \
	gdspy==1.6.13 \
	jsonschema2md==1.7.0 \
	klayout-pex==0.3.10 \
	klayout-vector-file-export-cli==0.5 \
	lctime==0.0.26 \
	librelane==3.0.2 \
	najaeda==0.5.4 \
	pygmid==1.2.12 \
	pyrtl==0.12 \
	pyuvm==4.0.1 \
	pyverilog==1.3.0 \
	"schemdraw[svgmath]==0.22" \
	scikit-rf==1.11.0 \
	siliconcompiler==0.37.5 \
	spicelib==1.5.1 \
	spyci==1.0.2

#FIXME There are currently issues with gmsh for arm64 Linux, so only install for x86_64
if [ "$(uname -m)" = "x86_64" ]; then
	echo "[INFO] Install x86_64-only EDA packages via PIP"
	pip3 install $PIP_FLAGS \
		gds2palace==0.1.19 \
		gmsh==4.15.2 \
		setupEM==0.1.22
fi

echo "[INFO] Installing CharLib"
pip3 install $PIP_FLAGS \
	git+https://github.com/stineje/charlib

#FIXME OpenRAM is removed for now, waiting for a release via PyPi
#echo "[INFO] Installing OpenRAM"
#pip3 install $PIP_FLAGS \
#	git+https://github.com/VLSIDA/OpenRAM

echo "[INFO] Installing Hdl21/vlsirtools"
pip3 install $PIP_FLAGS \
	git+https://github.com/dan-fritchman/Hdl21

echo "[INFO] Removing build dependencies"
apt-get purge -y libqhull-dev python3-dev
apt-get autoremove -y

#FIXME See https://github.com/librelane/librelane/issues/767
#echo "[INFO] Installing dev version of LibreLane"
#pip3 install $PIP_FLAGS \
#	https://github.com/librelane/librelane/tarball/dev

#FIXME Patch for mag_gds.tcl from https://github.com/librelane/librelane/commit/a07aa852
echo "[INFO] Patching LibreLane mag_gds.tcl"
MAG_GDS_TCL=$(python3 -c "import librelane; import os; print(os.path.join(os.path.dirname(librelane.__file__), 'scripts/magic/def/mag_gds.tcl'))")
if [ -f "$MAG_GDS_TCL" ]; then
	# Add "units microns" before the MAGIC_ZEROIZE_ORIGIN check
	if grep -q 'if { \$::env(MAGIC_ZEROIZE_ORIGIN) }' "$MAG_GDS_TCL"; then
		sed -i '/if { \$::env(MAGIC_ZEROIZE_ORIGIN) }/i units microns' "$MAG_GDS_TCL"
	else
		echo "[WARN] MAGIC_ZEROIZE_ORIGIN pattern not found in mag_gds.tcl, skipping patch"
	fi
	# Replace "property FIXED_BBOX [box values]" with explicit DIE_AREA coordinates
	if grep -q 'property FIXED_BBOX \[box values\]' "$MAG_GDS_TCL"; then
		sed -i 's/property FIXED_BBOX \[box values\]/property FIXED_BBOX [lindex $::env(DIE_AREA) 0]um [lindex $::env(DIE_AREA) 1]um [lindex $::env(DIE_AREA) 2]um [lindex $::env(DIE_AREA) 3]um/' "$MAG_GDS_TCL"
	else
		echo "[WARN] FIXED_BBOX pattern not found in mag_gds.tcl, skipping patch"
	fi
	echo "[INFO] LibreLane mag_gds.tcl patched successfully"
else
	echo "[WARN] Could not find mag_gds.tcl at $MAG_GDS_TCL"
fi

#FIXME Below line to be removed when LibreLane is fixed (dependency issue with newer pyosys versions)
echo "[INFO] Patching LibreLane pyosys/ys_common.py"
YS_COMMON_PY=$(python3 -c "import librelane; import os; print(os.path.join(os.path.dirname(librelane.__file__), 'scripts/pyosys/ys_common.py'))")
if [ -f "$YS_COMMON_PY" ]; then
	sed -i 's/__YOSYS_NAMESPACE_RTLIL_Design__std_vector_string_//' "$YS_COMMON_PY"
else
	echo "[WARN] Could not find ys_common.py at $YS_COMMON_PY"
fi

# Setup Qucs-S for IHP SG13G2
echo "[INFO] Setting up Qucs-S for IHP SG13G2"
python3 "$PDK_ROOT"/ihp-sg13g2/libs.tech/qucs-s/install.py --no-model-compile --no-qucs-check

# Setup .vacaskrc.toml for IHP SG13G2
echo "[INFO] Setting up VacasK for IHP SG13G2"
cp "$PDK_ROOT"/ihp-sg13g2/libs.tech/vacask/.vacaskrc.toml /headless

echo "[INFO] Install EDA packages via GEM"
gem install \
	rggen \
	rggen-verilog \
	rggen-vhdl \
	rggen-veryl

# Create dedicated gdsfactory8 venv for KLayout sky130A/B pcell compatibility.
# sky130A/B pcell libraries require gdsfactory==8.0.0 (the version that introduced
# the KLayout/kdb backend with kfactory 0.17.x APIs). The system gdsfactory
# (pinned to 9.20.6 for gf180mcuC/D compatibility) is incompatible with sky130 pcells.
# sak-pdk sets KLAYOUT_PYTHONPATH to this venv's site-packages when switching to
# sky130A/B, so KLayout prepends it to Python sys.path and pcell libraries load correctly.
echo "[INFO] Creating gdsfactory8 venv for KLayout sky130A/B pcell compatibility"
python3 -m venv /foss/tools/klayout_gdsfactory8
/foss/tools/klayout_gdsfactory8/bin/pip install --no-cache-dir "gdsfactory==8.0.0"

echo "[INFO] EDA package installation completed"
