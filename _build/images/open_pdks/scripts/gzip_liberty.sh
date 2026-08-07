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
# TRANSITION: the uncompressed .lib files are deliberately kept next to the
# .lib.gz files, so that user flows and scripts which reference the .lib paths
# directly keep working. This costs the disk space the compression would
# otherwise save. Drop the -k flag from the gzip call below (and announce it in
# the release notes) once the deprecation period of a few releases is over.

set -e
set -o pipefail

PDK_DIR="$1"

if [ -z "$PDK_DIR" ] || [ ! -d "$PDK_DIR/libs.ref" ]; then
	echo "[WARN] No libs.ref found in '$PDK_DIR', skipping Liberty compression."
	exit 0
fi

echo "[INFO] Compressing Liberty files in $PDK_DIR/libs.ref (keeping the uncompressed files)."
find "$PDK_DIR/libs.ref" -name "*.lib" -type f -exec gzip -k -f {} +

# Point the tool configurations to the compressed files. All tools in the image
# that read Liberty (yosys/ABC, OpenROAD, OpenSTA, librelane, kepler-formal)
# decompress .lib.gz transparently. Configurations outside of the PDK that still
# name the .lib files keep working, as those files are kept (see above).
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
