#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Install the ICsprout 55 nm open PDK (ICS55 v2, 55LLULP 1P6M, 1.2 V core and
# 2.5 V IO) as a digital-only PDK at $PDK_ROOT/ics55 (issue 464).
#
# Sources, each pinned (ICS55_* build arguments in the Dockerfile):
# - openecos-projects/icsprout55-pdk, branch main (ICS55 v2): the 9-track
#   standard cells ICsprout55_SC9T_BASIC_{SVT,HVT,LVT}, the GPIO library, the
#   tech LEF and the layer map. The Liberty and GDS views are release assets of
#   tag ICS55_PDK_ASSET_TAG, checked against the SHA-256 lists of the pinned
#   commit. ICsprout accepts only v2 layouts from the shuttle after 2026-11, so
#   the v1 branch ics55-v1 (7 tracks, 3.3 V IO) is not installed.
# - ckdur/icsprout55-openpdk: the DEF to GDS layer map, the KLayout layer
#   properties and the KLayout DRC and antenna decks, which are translated from
#   the vendor Calibre decks (unofficial, not foundry sign-off). They replace
#   the community deck of Ayoubbelguellaoui/ics55_klayout_drc, whose repository
#   was removed from GitHub (issue 475).
#
# The LibreLane configuration, the KLayout technology and the digital LVS deck
# are kept in this repository (images/open_pdks/ics55).
#
# Not shipped: the vendor docs (CC BY-NC-SA 4.0), the Calibre runsets, the CCS
# Liberty views (5.3 GB compressed) and any SPICE models (ICsprout does not
# publish them, openecos-projects/icsprout55-pdk#1).

set -e
set -o pipefail

PDK="ics55"
PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PDK_FILES_DIR="$(cd "$PDK_SCRIPT_DIR/../ics55" && pwd)"
PDK_DIR="$PDK_ROOT/$PDK"

ICS55_PDK_REPO_URL="${ICS55_PDK_REPO_URL:-https://github.com/openecos-projects/icsprout55-pdk.git}"
ICS55_PDK_REPO_COMMIT="${ICS55_PDK_REPO_COMMIT:-10054695f86cf26a96ea8aba69f7ec414afde593}"
ICS55_PDK_ASSET_TAG="${ICS55_PDK_ASSET_TAG:-v2-2026.10.28}"
ICS55_OPENPDK_REPO_URL="${ICS55_OPENPDK_REPO_URL:-https://github.com/ckdur/icsprout55-openpdk.git}"
ICS55_OPENPDK_REPO_COMMIT="${ICS55_OPENPDK_REPO_COMMIT:-efc7dfd61023f27cd3778f0dd7b19b63aa7bb17e}"

VTS="SVT HVT LVT"
IO_LIB="ICsprout_55LLULP1225_IO_0901"
# The 1.2 V corners (nominal, -10 %, +10 %). The 0.9 V to 1.1 V corners of the
# vendor are left out to keep the image smaller.
CORNERS="tt_v1p2_25c tt_v1p2_85c ss_v1p08_-40c ss_v1p08_85c ss_v1p08_125c ff_v1p32_-40c ff_v1p32_85c ff_v1p32_125c"
# Corners that keep their power tables. About 75 % of each vendor Liberty file
# are internal and leakage power tables, the other corners drop them (5.5 MB
# instead of 14 MB per file, compressed). Timing is complete in every corner.
POWER_CORNERS="tt_v1p2_25c tt_v1p2_85c"

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
	"/IP/" "/prtech/" "/techfile/" "/LICENSE" "/VERSION" "/release-assets.sha256" "/release-files.sha256" "!*.pdf"
clone_pinned "$ICS55_OPENPDK_REPO_URL" "$ICS55_OPENPDK_REPO_COMMIT" "$WORK_DIR/icsprout55-openpdk" \
	"/LICENSE" "/icsprout55/libs.tech/klayout/tech/ics55.map" "/icsprout55/libs.tech/klayout/tech/ics55.lyp" \
	"/icsprout55/libs.tech/klayout/tech/ics55.drc" "/icsprout55/libs.tech/klayout/tech/ics55_antenna.drc"

SRC="$WORK_DIR/icsprout55-pdk"
if [ "$(cat "$SRC/VERSION")" != "ics55-v2" ]; then
	echo "[ERROR] $ICS55_PDK_REPO_COMMIT is not ICS55 v2 (VERSION: $(cat "$SRC/VERSION"))."
	exit 1
fi

# Only the NLDM Liberty and the GDS archives. The checksums come from the
# pinned commit, so a re-published asset fails the build here.
echo "[INFO] Downloading the ICS55 release assets of $ICS55_PDK_ASSET_TAG."
ASSET_URL="https://github.com/openecos-projects/icsprout55-pdk/releases/download/$ICS55_PDK_ASSET_TAG"
mkdir -p "$WORK_DIR/assets"
grep -E '_(liberty_nldm|gds)\.tar\.bz2$' "$SRC/release-assets.sha256" > "$WORK_DIR/assets/SHA256SUMS"
awk '{ print $2 }' "$WORK_DIR/assets/SHA256SUMS" | while read -r asset; do
	wget --no-verbose --tries=3 --timeout=60 -O "$WORK_DIR/assets/$asset" "$ASSET_URL/$asset"
done
(cd "$WORK_DIR/assets" && sha256sum -c SHA256SUMS)

# The archives hold liberty/ or gds/ of one library directory of the vendor
# repository. release-files.sha256 lists the extracted files.
echo "[INFO] Extracting the release assets."
for vt in $VTS; do
	lib="ICsprout55_SC9T_BASIC_$vt"
	tar --no-same-owner -xjf "$WORK_DIR/assets/${lib}_liberty_nldm.tar.bz2" -C "$SRC/IP/STD_cell/$lib"
	tar --no-same-owner -xjf "$WORK_DIR/assets/${lib}_gds.tar.bz2" -C "$SRC/IP/STD_cell/$lib"
done
tar --no-same-owner -xjf "$WORK_DIR/assets/${IO_LIB}_gds.tar.bz2" -C "$SRC/IP/IO"
(cd "$SRC" && grep -E '/(gds/[^/]+\.gds|liberty/[^/]+_nldm\.lib)$' release-files.sha256 | sha256sum -c --quiet -)

# Drops the internal_power and leakage_power groups of a Liberty file. The
# cell_leakage_power attribute and all timing groups stay.
cat > "$WORK_DIR/strip_power.py" <<'EOF'
import re, sys
start = re.compile(r"^\s*(internal_power|leakage_power)\s*\(.*\)\s*\{")
depth = 0
with open(sys.argv[1]) as fi, open(sys.argv[2], "w") as fo:
    for line in fi:
        if depth == 0 and start.match(line):
            depth = line.count("{") - line.count("}")
            continue
        if depth > 0:
            depth += line.count("{") - line.count("}")
            continue
        fo.write(line)
if depth != 0:
    sys.exit("[ERROR] Unbalanced braces in " + sys.argv[1])
EOF

rm -rf "$PDK_DIR"
mkdir -p "$PDK_DIR/libs.ref" "$PDK_DIR/libs.tech"

# Standard cells: the vendor views, with "liberty" renamed to "lib" as in the
# other PDKs of the image. The doc directories only point to the manuals.
for vt in $VTS; do
	lib="ICsprout55_SC9T_BASIC_$vt"
	echo "[INFO] Installing $lib."
	src="$SRC/IP/STD_cell/$lib"
	dst="$PDK_DIR/libs.ref/$lib"
	mkdir -p "$dst/lib"
	for view in cdl cell_list gds lef verilog; do
		cp -r "$src/$view" "$dst/"
	done
	for corner in $CORNERS; do
		f="ICsprout55_9T${vt}_${corner}_basic_nldm.lib"
		case " $POWER_CORNERS " in
			*" $corner "*) cp "$src/liberty/$f" "$dst/lib/" ;;
			*) python3 "$WORK_DIR/strip_power.py" "$src/liberty/$f" "$dst/lib/$f" ;;
		esac
	done
done

echo "[INFO] Installing $IO_LIB."
IO_DST="$PDK_DIR/libs.ref/$IO_LIB"
mkdir -p "$IO_DST/lib"
for view in cdl cell_list gds lef verilog; do
	cp -r "$SRC/IP/IO/$view" "$IO_DST/"
done
cp "$SRC"/IP/IO/liberty/*.lib "$IO_DST/lib/"
# The vendor pad models use switch primitives (rnmos), which the Verilator lint
# of LibreLane rejects. LibreLane gets a port-only copy instead.
python3 - "$IO_DST/verilog/IC055L_GPIO3P3V_CDG.v" "$IO_DST/verilog/IC055L_GPIO3P3V_CDG_bb.v" <<'EOF'
import re, sys
src = open(sys.argv[1]).read()
out = ["// Port-only (blackbox) models of " + sys.argv[1].rsplit("/", 1)[-1] + ", written by install_ics55.sh\n"]
for m in re.finditer(r"^\s*module\s+(\w+)\s*(\([^;]*\))?\s*;(.*?)^\s*endmodule", src, re.M | re.S):
    decls = re.findall(r"^\s*((?:input|output|inout)\b[^;]*;)", m.group(3), re.M)
    out.append("(* blackbox *)\nmodule %s%s;\n" % (m.group(1), m.group(2) or "()"))
    out += ["  %s\n" % " ".join(d.split()) for d in decls]
    out.append("endmodule\n\n")
open(sys.argv[2], "w").write("".join(out))
EOF

# Compress the Liberty files (about 0.6 GB uncompressed), -9 as in
# gzip_liberty.sh. Every tool in the image that reads Liberty takes .lib.gz.
echo "[INFO] Compressing the Liberty files."
find "$PDK_DIR/libs.ref" -name "*.lib" -type f -exec gzip -9 -f {} +

# Technology: tech LEF and layer map from the vendor, KLayout technology,
# LibreLane configuration and digital LVS from this repository, DEF to GDS
# map, layer properties and DRC decks from the port.
echo "[INFO] Installing the KLayout and LibreLane collateral."
mkdir -p "$PDK_DIR/libs.tech/techlef" "$PDK_DIR/libs.tech/klayout/tech"
cp "$SRC"/prtech/techLEF/*.lef "$PDK_DIR/libs.tech/techlef/"
cp "$SRC/techfile/icsprout55.layermap" "$PDK_DIR/libs.tech/"
cp -r "$PDK_FILES_DIR/libs.tech/." "$PDK_DIR/libs.tech/"
cp "$PDK_FILES_DIR/README.md" "$PDK_DIR/README.md"
PORT_TECH="$WORK_DIR/icsprout55-openpdk/icsprout55/libs.tech/klayout/tech"
cp "$PORT_TECH/ics55.map" "$PORT_TECH/ics55.lyp" "$PDK_DIR/libs.tech/klayout/tech/"
cp "$WORK_DIR/icsprout55-openpdk/LICENSE" "$PDK_DIR/libs.tech/klayout/tech/LICENSE.icsprout55-openpdk"
mkdir -p "$PDK_DIR/libs.tech/klayout/drc"
cp "$PORT_TECH/ics55.drc" "$PORT_TECH/ics55_antenna.drc" "$PDK_DIR/libs.tech/klayout/drc/"
cp "$WORK_DIR/icsprout55-openpdk/LICENSE" "$PDK_DIR/libs.tech/klayout/drc/LICENSE"

# The synthesis maps and cell lists of this repository name the SVT cells. The
# HVT and LVT libraries have the same cells and pins, only the suffix differs.
LL="$PDK_DIR/libs.tech/librelane"
for vt in HVT LVT; do
	for f in "$LL"/ICsprout55_SC9T_BASIC_SVT/*.v "$LL"/ICsprout55_SC9T_BASIC_SVT/*.cells; do
		sed "s/_9TSVT\b/_9T$vt/g" "$f" > "$LL/ICsprout55_SC9T_BASIC_$vt/$(basename "$f")"
	done
done

cp "$SRC/LICENSE" "$PDK_DIR/LICENSE"
{
	echo "ICS55 open PDK v2 (digital-only), installed by IIC-OSIC-TOOLS"
	echo "icsprout55-pdk $ICS55_PDK_REPO_URL $ICS55_PDK_REPO_COMMIT (release assets $ICS55_PDK_ASSET_TAG)"
	echo "icsprout55-openpdk $ICS55_OPENPDK_REPO_URL $ICS55_OPENPDK_REPO_COMMIT"
} > "$PDK_DIR/SOURCES"

chmod -R u+w,a+rX "$PDK_DIR"

# Every LibreLane path must resolve, otherwise the flow fails late at the step
# that reads the missing file.
echo "[INFO] Checking the installed views."
MISSING=0
for vt in $VTS; do
	lib="ICsprout55_SC9T_BASIC_$vt"
	base="ICsprout55_9T${vt}_basic"
	files="libs.ref/$lib/lef/$base.lef libs.ref/$lib/gds/$base.gds libs.ref/$lib/cdl/$base.cdl"
	files="$files libs.ref/$lib/verilog/$base.v libs.tech/librelane/$lib/config.tcl"
	files="$files libs.tech/librelane/$lib/latch_map.v libs.tech/librelane/$lib/synth_exclude.cells"
	for corner in $CORNERS; do
		files="$files libs.ref/$lib/lib/ICsprout55_9T${vt}_${corner}_basic_nldm.lib.gz"
	done
	for f in $files; do
		if [ ! -f "$PDK_DIR/$f" ]; then
			echo "[ERROR] $PDK_DIR/$f is missing."
			MISSING=1
		fi
	done
done
if [ "$MISSING" -ne 0 ]; then
	exit 1
fi

echo "[INFO] ICS55 PDK installed to $PDK_DIR ($(du -sh "$PDK_DIR" | cut -f1))."
