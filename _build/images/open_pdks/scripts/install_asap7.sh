#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Install the ASAP7 7 nm FinFET predictive PDK (ASU and Arm Research) to
# $PDK_ROOT/asap7. ASAP7 is predictive and not manufacturable. The Calibre
# decks of ASAP7 are not redistributable and are not part of this install.
#
# Sources, each at a pinned revision (ARGs in the Dockerfile):
#   asap7_pdk_r1p7        HSPICE BSIM-CMG model cards, design rule manual
#   asap7sc7p5t_28        7.5-track standard cells: CDL and Verilog
#   OpenROAD-flow-scripts platform asap7: LEF, NLDM Liberty, GDS, KLayout
#                         layer properties, OpenROAD and Yosys helper files
#   ASAP7_for_KLayout     KLayout DRC deck written from the DRM
#   VA-Models             BSIM-CMG 111.2.1 Verilog-A for ngspice and VACASK
# The local overlay in images/open_pdks/asap7 adds the KLayout technology,
# LVS deck, DEF layer map, LibreLane configuration, simulator setup files,
# xschem symbols and pygmid scripts.
#
# The 6-track library asap7sc6t_26 is not installed.
set -e
set -o pipefail

PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_DIR="$(cd "$PDK_SCRIPT_DIR/../asap7" && pwd)"
PDK="asap7"
SCL="asap7sc7p5t"
PDK_DIR="$PDK_ROOT/$PDK"
SRC_DIR="/tmp/asap7-src"
VTS="R L SL SRAM"

if [ -z "$PDK_ROOT" ]; then
	echo "[ERROR] PDK_ROOT is not set."
	exit 1
fi
for v in ASAP7_PDK_R1P7_REPO_URL ASAP7_PDK_R1P7_REPO_COMMIT ASAP7SC7P5T_28_REPO_URL ASAP7SC7P5T_28_REPO_COMMIT \
	OPENROAD_FLOW_SCRIPTS_REPO_URL OPENROAD_FLOW_SCRIPTS_REPO_COMMIT ASAP7_FOR_KLAYOUT_REPO_URL \
	ASAP7_FOR_KLAYOUT_REPO_COMMIT VA_MODELS_REPO_URL VA_MODELS_REPO_COMMIT; do
	if [ -z "${!v}" ]; then
		echo "[ERROR] $v is not set."
		exit 1
	fi
done

echo "[INFO] Installing the ASAP7 PDK to $PDK_DIR."
rm -rf "$PDK_DIR" "$SRC_DIR"
mkdir -p "$PDK_DIR" "$SRC_DIR"

# Clone a pinned commit, optionally restricted to a sparse set of paths.
# blob:none + --no-checkout fetches file contents for the pinned commit only.
clone_pinned() {
	local url="$1" commit="$2" dir="$3"
	shift 3
	git clone --filter=blob:none --no-checkout "$url" "$dir"
	if [ $# -gt 0 ]; then
		git -C "$dir" sparse-checkout set --no-cone "$@"
	fi
	git -C "$dir" checkout "$commit"
}

cd "$SRC_DIR"
clone_pinned "$ASAP7_PDK_R1P7_REPO_URL" "$ASAP7_PDK_R1P7_REPO_COMMIT" pdk \
	/LICENSE /README.md /models/ /docs/asap7_drm_201207a.pdf
# The library repository is about 3 GB, mostly CCS Liberty and datasheets.
# Only the views ORFS does not carry are taken from it.
clone_pinned "$ASAP7SC7P5T_28_REPO_URL" "$ASAP7SC7P5T_28_REPO_COMMIT" scl \
	/LICENSE /license/ /CDL/LVS/ /Verilog/
clone_pinned "$OPENROAD_FLOW_SCRIPTS_REPO_URL" "$OPENROAD_FLOW_SCRIPTS_REPO_COMMIT" orfs \
	/LICENSE_BUILD_RUN_SCRIPTS /flow/platforms/asap7/KLayout/ /flow/platforms/asap7/lef/ /flow/platforms/asap7/gds/ \
	"/flow/platforms/asap7/lib/NLDM/asap7sc7p5t_*_nldm_2*" /flow/platforms/asap7/yoSys/ \
	/flow/platforms/asap7/rcx_patterns.rules /flow/platforms/asap7/setRC.tcl
clone_pinned "$ASAP7_FOR_KLAYOUT_REPO_URL" "$ASAP7_FOR_KLAYOUT_REPO_COMMIT" klayout
clone_pinned "$VA_MODELS_REPO_URL" "$VA_MODELS_REPO_COMMIT" va-models /code/bsimcmg/vacode/
ORFS_PLATFORM="$SRC_DIR/orfs/flow/platforms/asap7"

# Local overlay first, the upstream files below go next to it
# -r, not -a: the files would keep the owner they have in the build context
cp -r "$OVERLAY_DIR/." "$PDK_DIR/"

# Licenses and documentation
cp pdk/LICENSE "$PDK_DIR/LICENSE"
mkdir -p "$PDK_DIR/libs.doc"
cp pdk/docs/asap7_drm_201207a.pdf "$PDK_DIR/libs.doc/"

# Standard cells
echo "[INFO] Installing the $SCL standard cells (all four VT flavors)."
REF="$PDK_DIR/libs.ref/$SCL"
mkdir -p "$REF"/{lef,techlef,lib,gds,cdl,verilog}
cp scl/LICENSE "$REF/LICENSE"
cp -r scl/license "$REF/license"
cp "$ORFS_PLATFORM"/lef/asap7_tech_1x_201209.lef "$REF/techlef/"
for vt in $VTS; do
	cp "$ORFS_PLATFORM/lef/asap7sc7p5t_28_${vt}_1x_220121a.lef" "$REF/lef/"
	cp "$ORFS_PLATFORM/gds/asap7sc7p5t_28_${vt}_220121a.gds" "$REF/gds/"
	cp "scl/CDL/LVS/asap7sc7p5t_28_${vt}.cdl" "$REF/cdl/"
	python3 "$PDK_SCRIPT_DIR/fix_asap7_cdl.py" "$REF/cdl/asap7sc7p5t_28_${vt}.cdl" "$vt"
done
cp scl/Verilog/asap7sc7p5t_*.v "$REF/verilog/"
# NLDM only: the CCS Liberty files are 2.7 GB. ORFS ships most of them gzipped
# already, the rest is compressed here. No uncompressed copies are kept.
# The revisions are the ones ORFS config.mk uses. ORFS also carries a newer
# SIMPLE RVT FF file (250407) that its config.mk does not use, it is left out.
for f in "AO_*_211120" "INVBUF_*_220122" "OA_*_211120" "SEQ_*_220123" "SIMPLE_*_211120"; do
	# shellcheck disable=SC2086 # $f is a glob
	cp "$ORFS_PLATFORM"/lib/NLDM/asap7sc7p5t_$f.lib* "$REF/lib/"
done
find "$REF/lib" -name "*.lib" -type f -exec gzip -9 -f {} +
LIB_COUNT=$(find "$REF/lib" -name "*.lib.gz" | wc -l)
# 5 groups (AO, INVBUF, OA, SEQ, SIMPLE) x 4 VTs x 3 corners
if [ "$LIB_COUNT" -ne 60 ]; then
	echo "[ERROR] Expected 60 Liberty files in $REF/lib, found $LIB_COUNT."
	exit 1
fi

# KLayout: layer properties from ORFS, DRC deck from ASAP7_for_KLayout
echo "[INFO] Installing the KLayout files."
KL="$PDK_DIR/libs.tech/klayout"
mkdir -p "$KL/tech" "$KL/drc"
cp "$ORFS_PLATFORM/KLayout/asap7.lyp" "$KL/tech/asap7.lyp"
cp klayout/drc/drc_ASAP7.lydrc "$KL/drc/asap7.lydrc"
cp klayout/LICENSE "$KL/drc/LICENSE"
python3 "$PDK_SCRIPT_DIR/fix_asap7_drc_deck.py" "$KL/drc/asap7.lydrc"

# LibreLane: Yosys maps and RC data from ORFS
LL="$PDK_DIR/libs.tech/librelane"
for vt in R L SL; do
	cp "$ORFS_PLATFORM/yoSys/cells_latch_${vt}.v" "$ORFS_PLATFORM/yoSys/cells_adders_${vt}.v" \
		"$ORFS_PLATFORM/yoSys/cells_clkgate_${vt}.v" "$LL/common/"
done
cp "$ORFS_PLATFORM/rcx_patterns.rules" "$ORFS_PLATFORM/setRC.tcl" "$LL/common/"
cp orfs/LICENSE_BUILD_RUN_SCRIPTS "$LL/common/LICENSE.orfs"

# SPICE models: original HSPICE cards plus the converted libraries
echo "[INFO] Converting the BSIM-CMG model cards."
mkdir -p "$PDK_DIR/libs.tech/hspice"
cp pdk/models/hspice/7nm_??_160803.pm "$PDK_DIR/libs.tech/hspice/"
python3 "$PDK_SCRIPT_DIR/asap7_models.py" pdk/models/hspice "$PDK_DIR/libs.tech"

# BSIM-CMG 111.2.1 for ngspice and VACASK, generic target so the object runs on
# any host CPU. Built from the pinned VA-Models revision rather than reusing
# the copy the ngspice image builds from the VA-Models head.
echo "[INFO] Compiling BSIM-CMG for ngspice and VACASK."
mkdir -p "$PDK_DIR/libs.tech/ngspice/osdi" "$PDK_DIR/libs.tech/vacask/osdi"
cd "$SRC_DIR/va-models/code/bsimcmg/vacode"
"$TOOLS/openvaf/bin/openvaf" --target_cpu generic bsimcmg.va -o "$PDK_DIR/libs.tech/ngspice/osdi/bsimcmg.osdi"
cp "$PDK_DIR/libs.tech/ngspice/osdi/bsimcmg.osdi" "$PDK_DIR/libs.tech/vacask/osdi/bsimcmg.osdi"
mkdir -p "$PDK_DIR/libs.tech/verilog-a/bsimcmg"
cp ./*.va ./*.include ./*.vams LICENSE.txt "$PDK_DIR/libs.tech/verilog-a/bsimcmg/"
cd "$SRC_DIR"

# Record the source revisions
{
	echo "asap7_pdk_r1p7 $ASAP7_PDK_R1P7_REPO_COMMIT"
	echo "asap7sc7p5t_28 $ASAP7SC7P5T_28_REPO_COMMIT"
	echo "OpenROAD-flow-scripts $OPENROAD_FLOW_SCRIPTS_REPO_COMMIT"
	echo "ASAP7_for_KLayout $ASAP7_FOR_KLAYOUT_REPO_COMMIT"
	echo "VA-Models $VA_MODELS_REPO_COMMIT"
} > "$PDK_DIR/SOURCES"

# Every path the LibreLane configuration names has to exist
echo "[INFO] Checking the files the LibreLane configuration refers to."
MISSING=0
for f in "$REF/techlef/asap7_tech_1x_201209.lef" "$KL/tech/asap7.lyt" "$KL/tech/asap7.lyp" "$KL/tech/asap7.map" \
	"$KL/drc/asap7.lydrc" "$KL/lvs/asap7.lvs" "$LL/common/tracks.info" \
	"$LL/common/rcx_patterns.rules"; do
	if [ ! -f "$f" ]; then
		echo "[ERROR] $f is missing."
		MISSING=1
	fi
done
if [ "$MISSING" -ne 0 ]; then
	exit 1
fi

rm -rf "$SRC_DIR"

# The overlay comes from the build context, which keeps the umask of the build
# host (027 on the maintainers' hosts), so make everything world-readable.
chmod -R a+rX "$PDK_DIR"

echo "[INFO] ASAP7 PDK installation complete."
