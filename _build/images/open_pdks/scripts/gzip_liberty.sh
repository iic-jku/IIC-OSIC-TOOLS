#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Compress the Liberty (.lib) files of a PDK and adjust the references in the
# tool configuration files shipped with the PDK.
#
# Usage: gzip_liberty.sh <pdk-directory>
#
# Only libs.ref holds Liberty files. libs.tech/{ngspice,xyce,vacask,qucs-s}
# uses the same .lib extension for SPICE model libraries, which the simulators
# read uncompressed, so those directories are left untouched.
#
# The uncompressed .lib files are removed, only the .lib.gz files ship. Every
# tool in the image that reads Liberty takes .lib.gz.

set -e
set -o pipefail

PDK_DIR="$1"

if [ -z "$PDK_DIR" ] || [ ! -d "$PDK_DIR/libs.ref" ]; then
	echo "[WARN] No libs.ref found in '$PDK_DIR', skipping Liberty compression."
	exit 0
fi

echo "[INFO] Compressing Liberty files in $PDK_DIR/libs.ref."
find "$PDK_DIR/libs.ref" -name "*.lib" -type f -exec gzip -f {} +

# A PDK can borrow a Liberty file from another one through a *renamed* symlink
# -- ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell_hv/lib/*.lib points at the
# SG13G2 files, so that the LibreLane paths derived from $STD_CELL_LIBRARY
# resolve. Those are not compressed above (find -type f does not follow
# symlinks) and the .gz made on the other side carries the other PDK's name,
# while the configuration rewritten below asks for the local one. Mirror the
# link for the compressed file too: same relative target, .gz appended. The
# .lib link itself is removed, as its target is gone once the other PDK has
# been compressed.
# Borrowing a whole directory (libs.ref/sg13cmos5l_sram) needs none of this,
# since the directory resolves to the other PDK with its .lib.gz files in it.
find "$PDK_DIR/libs.ref" -name "*.lib" -type l | while read -r lib_link; do
	if [ -e "$lib_link.gz" ]; then
		rm "$lib_link"
		continue
	fi
	link_target=$(readlink "$lib_link")
	case "$link_target" in
		/*) target_gz="$link_target.gz" ;;
		*)  target_gz="$(dirname "$lib_link")/$link_target.gz" ;;
	esac
	if [ -e "$target_gz" ]; then
		ln -s "$link_target.gz" "$lib_link.gz"
		rm "$lib_link"
		echo "[INFO] Linked $(basename "$lib_link").gz to the compressed file it borrows."
	else
		echo "[WARN] $lib_link is a symlink whose target has no .gz, references to it will not resolve."
	fi
done

# Point the tool configurations to the compressed files. All tools in the image
# that read Liberty (yosys/ABC, OpenROAD, OpenSTA, librelane, kepler-formal)
# decompress .lib.gz transparently.
#
# The expression only rewrites ".lib" when it is not followed by another
# extension, which keeps ".lib.json" references intact and makes a repeated run
# a no-op.
for tool_dir in librelane openlane qflow; do
	[ -d "$PDK_DIR/libs.tech/$tool_dir" ] || continue
	# --follow-symlinks keeps symlinked configuration files (used by the IHP PDKs)
	# symlinks instead of replacing them with a regular file.
	grep -rlZ '\.lib' "$PDK_DIR/libs.tech/$tool_dir" |
		xargs -0 -r sed -i --follow-symlinks 's/\.lib\([^A-Za-z0-9_.]\|$\)/.lib.gz\1/g'
done
