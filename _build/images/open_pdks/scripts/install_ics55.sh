#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Install the ICsprout 55 nm open PDK (ICS55, 55LLULP 1P6M) as a digital-only
# PDK at $PDK_ROOT/ics55 (issue 464).
#
# Sources, each pinned (ICS55_* build arguments in the Dockerfile):
# - openecos-projects/icsprout55-pdk, branch ics55-v1: the 7-track standard
#   cells ics55_LLSC_H7C{R,H,L}, the IO library, the tech LEF and the layer
#   map. The Liberty and GDS views are release assets of tag
#   ICS55_PDK_ASSET_TAG, checked against the SHA-256 list below.
# - Ayoubbelguellaoui/ics55_klayout_drc: the community KLayout DRC deck
#   (unofficial, not foundry sign-off).
# - ckdur/icsprout55-openpdk: only the per-library LibreLane collateral
#   (tracks, synthesis maps, exclude lists, pad config), the DEF to GDS layer
#   map and the CDL converter. Its regenerated cells, SPICE models, RCX rules
#   and Magic files are not used.
#
# The LibreLane configuration, the KLayout technology and the digital LVS deck
# are kept in this repository (images/open_pdks/ics55).
#
# Not shipped: the vendor docs (CC BY-NC-SA 4.0), the Calibre runsets and any
# SPICE models (ICsprout does not publish them,
# openecos-projects/icsprout55-pdk#1).

set -e
set -o pipefail

PDK="ics55"
PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PDK_FILES_DIR="$(cd "$PDK_SCRIPT_DIR/../ics55" && pwd)"
PDK_DIR="$PDK_ROOT/$PDK"

ICS55_PDK_REPO_URL="${ICS55_PDK_REPO_URL:-https://github.com/openecos-projects/icsprout55-pdk.git}"
ICS55_PDK_REPO_COMMIT="${ICS55_PDK_REPO_COMMIT:-bedd656c89ae7c6938c8538e8d8e7b3f018c55a9}"
ICS55_PDK_ASSET_TAG="${ICS55_PDK_ASSET_TAG:-v1.10.103}"
ICS55_KLAYOUT_DRC_REPO_URL="${ICS55_KLAYOUT_DRC_REPO_URL:-https://github.com/Ayoubbelguellaoui/ics55_klayout_drc.git}"
ICS55_KLAYOUT_DRC_REPO_COMMIT="${ICS55_KLAYOUT_DRC_REPO_COMMIT:-e084bab316af8626f4ce48512106804142f12d94}"
ICS55_OPENPDK_REPO_URL="${ICS55_OPENPDK_REPO_URL:-https://github.com/ckdur/icsprout55-openpdk.git}"
ICS55_OPENPDK_REPO_COMMIT="${ICS55_OPENPDK_REPO_COMMIT:-efc7dfd61023f27cd3778f0dd7b19b63aa7bb17e}"

# SHA-256 of the release assets of ICS55_PDK_ASSET_TAG. Upstream ships no
# checksum file for v1, so a re-published asset fails the build here.
ASSET_SHA256="
9c06a04e52af68163ec027b6f0054e3c896b0f18a9cac699aad1813b7b65e481  ics55_LLSC_H7CH_liberty.tar.bz2
5b064b347aabe1cf1da1406ad6be59fd505bcc83601d6b40cb13196fb87a6e79  ics55_LLSC_H7CL_liberty.tar.bz2
6c6b9c2102a7efd885558dd60892fdb6d2f9dad81a63ec872c06e398ab262fbf  ics55_LLSC_H7CR_liberty.tar.bz2
6268684fdd0784087adc1a972125f9001bc9761c3142ab954d2a9eade53d5490  ics55_LLSC_H7CH_gds.tar.bz2
9a643ae864d178f45fec4aa59dc98f0420894760d8a431ce0fd640b97e1c2f68  ics55_LLSC_H7CL_gds.tar.bz2
525a7a486e15e36888e4ce08887c946cd16c60dc2c90819fb493d865ed38cc2b  ics55_LLSC_H7CR_gds.tar.bz2
47d248be322a6f054a0ab11fe2f2ee83ad76f9ce15d6f4cd53a81c8d08c7693b  ICsprout_55LLULP1233_IO_251013_gds.tar.bz2
"

STD_LIBS="ics55_LLSC_H7CR ics55_LLSC_H7CH ics55_LLSC_H7CL"
IO_LIB="ICsprout_55LLULP1233_IO_251013"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

clone_pinned() {
	# $1 URL, $2 commit, $3 target directory, further arguments: sparse paths
	local url="$1" commit="$2" dir="$3"
	shift 3
	git clone --filter=blob:none --no-checkout "$url" "$dir"
	if [ $# -gt 0 ]; then
		git -C "$dir" sparse-checkout set --no-cone "$@"
	fi
	git -C "$dir" checkout --quiet "$commit"
}

echo "[INFO] Fetching the ICS55 PDK sources."
# The submodules (PLL, DDR PHY) are not needed, so they are not initialized.
clone_pinned "$ICS55_PDK_REPO_URL" "$ICS55_PDK_REPO_COMMIT" "$WORK_DIR/icsprout55-pdk" \
	"/IP/" "/prtech/" "/techfile/" "/LICENSE" "/README.md" "!*.pdf"
clone_pinned "$ICS55_KLAYOUT_DRC_REPO_URL" "$ICS55_KLAYOUT_DRC_REPO_COMMIT" "$WORK_DIR/ics55_klayout_drc"
clone_pinned "$ICS55_OPENPDK_REPO_URL" "$ICS55_OPENPDK_REPO_COMMIT" "$WORK_DIR/icsprout55-openpdk" \
	"/LICENSE" "/hacking/cdl_convert.py" "/icsprout55/libs.tech/librelane/ics55_LLSC_H7C*/" \
	"/icsprout55/libs.tech/librelane/ICsprout_55LLULP1233_IO_251013/" \
	"/icsprout55/libs.tech/klayout/tech/ics55.map"

echo "[INFO] Downloading the ICS55 release assets of $ICS55_PDK_ASSET_TAG."
ASSET_URL="https://github.com/openecos-projects/icsprout55-pdk/releases/download/$ICS55_PDK_ASSET_TAG"
mkdir -p "$WORK_DIR/assets"
echo "$ASSET_SHA256" | awk 'NF == 2 { print $2 }' | while read -r asset; do
	wget --no-verbose --tries=3 --timeout=60 -O "$WORK_DIR/assets/$asset" "$ASSET_URL/$asset"
done
(cd "$WORK_DIR/assets" && echo "$ASSET_SHA256" | awk 'NF == 2' | sha256sum -c -)

# The vendor CDLs define helper subcircuits (INV, TG) repeatedly, use the CDL
# "/" separator and parameters that are not declared, which KLayout rejects.
# The port's converter writes a CDL that KLayout reads and LibreLane can
# concatenate with others (see its header for the changes).
convert_cdl() {
	python3 "$WORK_DIR/icsprout55-openpdk/hacking/cdl_convert.py" "$@"
}

SRC="$WORK_DIR/icsprout55-pdk"
STD_SRC="$SRC/IP/STD_cell/ics55_LLSC_H7C_V1p10C100"
rm -rf "$PDK_DIR"
mkdir -p "$PDK_DIR/libs.ref" "$PDK_DIR/libs.tech"

# Standard cells: the vendor views, with "liberty" renamed to "lib" as in the
# other PDKs of the image. The doc directories hold the CC BY-NC-SA datasheets.
for lib in $STD_LIBS; do
	echo "[INFO] Installing $lib."
	dst="$PDK_DIR/libs.ref/$lib"
	mkdir -p "$dst"
	for view in cdl cell_list lef verilog; do
		cp -r "$STD_SRC/$lib/$view" "$dst/"
	done
	convert_cdl "$STD_SRC/$lib/cdl/$lib.cdl" "$dst/cdl/$lib.cdl"
	# The release archives store UID 417800042, which root tar keeps and rootless
	# podman cannot map on pull.
	tar --no-same-owner -xjf "$WORK_DIR/assets/${lib}_liberty.tar.bz2" -C "$dst"
	tar --no-same-owner -xjf "$WORK_DIR/assets/${lib}_gds.tar.bz2" -C "$dst"
	mv "$dst/liberty" "$dst/lib"
done

echo "[INFO] Installing $IO_LIB."
IO_SRC="$SRC/IP/IO/$IO_LIB"
IO_DST="$PDK_DIR/libs.ref/$IO_LIB"
mkdir -p "$IO_DST/lib"
for view in cdl cell_list lef verilog; do
	cp -r "$IO_SRC/$view" "$IO_DST/"
done
# --lef adds empty subcircuits for the corner and spacer cells, which
# OpenROAD write_cdl needs for every master.
convert_cdl "$IO_SRC/cdl/ICSIOA_N55_3P3.cdl" "$IO_DST/cdl/ICSIOA_N55_3P3.cdl" \
	--lef "$IO_SRC/lef/ICSIOA_N55_3P3_1P6M1TM_ecos.lef"
cp "$IO_SRC"/liberty/*.lib "$IO_DST/lib/"
tar --no-same-owner -xjf "$WORK_DIR/assets/${IO_LIB}_gds.tar.bz2" -C "$IO_DST"

# Compress the Liberty files (about 1.7 GB uncompressed). Every tool in the
# image that reads Liberty takes .lib.gz.
echo "[INFO] Compressing the Liberty files."
find "$PDK_DIR/libs.ref" -name "*.lib" -type f -exec gzip -f {} +

# Technology: tech LEF and layer map from the vendor, KLayout technology,
# layer properties and digital LVS from this repository, DEF to GDS map from
# the port.
echo "[INFO] Installing the KLayout and LibreLane collateral."
mkdir -p "$PDK_DIR/libs.tech/techlef" "$PDK_DIR/libs.tech/klayout/tech" "$PDK_DIR/libs.tech/librelane"
cp "$SRC"/prtech/techLEF/*.lef "$PDK_DIR/libs.tech/techlef/"
cp "$SRC/techfile/icsprout55.layermap" "$PDK_DIR/libs.tech/"
cp -r "$PDK_FILES_DIR/libs.tech/." "$PDK_DIR/libs.tech/"
cp "$PDK_FILES_DIR/README.md" "$PDK_DIR/README.md"
cp "$WORK_DIR/icsprout55-openpdk/icsprout55/libs.tech/klayout/tech/ics55.map" "$PDK_DIR/libs.tech/klayout/tech/"

# Community KLayout DRC deck. Its generated .lyp is the layer properties of the
# technology (same layer map). The .lyt and .lm of the repo are not used: the
# technology file is kept in this repository.
DRC_SRC="$WORK_DIR/ics55_klayout_drc"
mkdir -p "$PDK_DIR/libs.tech/klayout/drc"
cp "$DRC_SRC"/klayout/drc/*.rb "$DRC_SRC"/klayout/drc/*.drc "$DRC_SRC/klayout/drc/RULE_INDEX.md" \
	"$PDK_DIR/libs.tech/klayout/drc/"
cp "$DRC_SRC/LICENSE" "$PDK_DIR/libs.tech/klayout/drc/LICENSE"
cp "$DRC_SRC/klayout/tech/icsprout55.lyp" "$PDK_DIR/libs.tech/klayout/tech/ics55.lyp"

# Per-library LibreLane collateral of the port. Its config.tcl files are
# replaced by the ones from this repository (copied above), which do not rely
# on the regenerated cells, the antenna Liberty or the RCX rules of the port.
PORT_LL="$WORK_DIR/icsprout55-openpdk/icsprout55/libs.tech/librelane"
for lib in $STD_LIBS; do
	for f in tracks.info latch_map.v mux2_map.v mux4_map.v tribuff_map.v synth_exclude.cells pnr_exclude.cells; do
		cp "$PORT_LL/$lib/$f" "$PDK_DIR/libs.tech/librelane/$lib/$f"
	done
done
# Pad sites, cells and fillers of the IO library for the LibreLane Chip flow.
mkdir -p "$PDK_DIR/libs.tech/librelane/$IO_LIB"
cp "$PORT_LL/$IO_LIB/config.tcl" "$PDK_DIR/libs.tech/librelane/$IO_LIB/config.tcl"
cp "$WORK_DIR/icsprout55-openpdk/LICENSE" "$PDK_DIR/libs.tech/librelane/LICENSE.icsprout55-openpdk"

cp "$SRC/LICENSE" "$PDK_DIR/LICENSE"
{
	echo "ICS55 open PDK (digital-only), installed by IIC-OSIC-TOOLS"
	echo "icsprout55-pdk $ICS55_PDK_REPO_URL $ICS55_PDK_REPO_COMMIT (release assets $ICS55_PDK_ASSET_TAG)"
	echo "ics55_klayout_drc $ICS55_KLAYOUT_DRC_REPO_URL $ICS55_KLAYOUT_DRC_REPO_COMMIT"
	echo "icsprout55-openpdk $ICS55_OPENPDK_REPO_URL $ICS55_OPENPDK_REPO_COMMIT"
} > "$PDK_DIR/SOURCES"

chmod -R u+w,a+rX "$PDK_DIR"

# Every LibreLane path must resolve, otherwise the flow fails late at the step
# that reads the missing file.
echo "[INFO] Checking the installed views."
MISSING=0
for lib in $STD_LIBS; do
	for f in "lef/${lib}_ecos.lef" "gds/${lib}_M2.gds" "cdl/$lib.cdl" "verilog/$lib.v" \
		"lib/${lib}_typ_tt_1p2_25_nldm.lib.gz" "lib/${lib}_ss_rcworst_1p08_125_nldm.lib.gz" \
		"lib/${lib}_ff_rcbest_1p32_m40_nldm.lib.gz"; do
		if [ ! -f "$PDK_DIR/libs.ref/$lib/$f" ]; then
			echo "[ERROR] $PDK_DIR/libs.ref/$lib/$f is missing."
			MISSING=1
		fi
	done
done
if [ "$MISSING" -ne 0 ]; then
	exit 1
fi

echo "[INFO] ICS55 PDK installed to $PDK_DIR ($(du -sh "$PDK_DIR" | cut -f1))."
