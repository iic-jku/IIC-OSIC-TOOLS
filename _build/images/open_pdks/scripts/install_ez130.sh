#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Install ETH Zurich's EZ130 8T standard-cell library into the IHP SG13G2 PDK,
# next to sg13g2_stdcell as libs.ref/ez130_8t.
#
# The archive is pinned by URL and SHA-256 (see the EZ130_* build arguments in
# the Dockerfile), so a re-published or renamed file fails the build instead
# of silently changing the image. Landing page: https://iip.ethz.ch/ez-library/
#
# The archive ships its own technology LEFs (ez130_sg13g2_tech.lef and
# ez130_sg13cmos5l_tech.lef, derived from the IHP ones with changed routing
# pitches/offsets). Use those with the cell LEF, not the stock sg13g2_tech.lef.
#
# Liberty compression is left to gzip_liberty.sh, which install_ihp.sh runs
# over the whole PDK after this script.

set -e
set -o pipefail

PDK="ihp-sg13g2"
LIB_NAME="ez130_8t"
EZ130_URL="${EZ130_URL:-https://iis-people.ee.ethz.ch/~iisdatasets/iip/ezlib/ihp130_8t/v1p1/ez130_8t_v1p1.zip}"
EZ130_SHA256="${EZ130_SHA256:-4c072bae2089f13d258f7c8a9b2bdb4e74002791cc30be89f6d2beac3069d517}"
TARGET_DIR="$PDK_ROOT/$PDK/libs.ref/$LIB_NAME"

if [ ! -d "$PDK_ROOT/$PDK/libs.ref" ]; then
	echo "[ERROR] $PDK_ROOT/$PDK/libs.ref not found, install the IHP PDK first."
	exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "[INFO] Downloading the EZ130 8T library from $EZ130_URL"
wget --no-verbose --tries=3 --timeout=60 -O "$WORK_DIR/ez130.zip" "$EZ130_URL"
echo "$EZ130_SHA256  $WORK_DIR/ez130.zip" | sha256sum -c -

unzip -q "$WORK_DIR/ez130.zip" -d "$WORK_DIR/extract"

# The archive has a single versioned top-level directory (ez130_8t_v1p1/).
shopt -s nullglob
SRC_DIRS=("$WORK_DIR"/extract/*/)
shopt -u nullglob
if [ "${#SRC_DIRS[@]}" -ne 1 ] || [ ! -f "${SRC_DIRS[0]}lef/$LIB_NAME.lef" ]; then
	echo "[ERROR] Unexpected EZ130 archive layout, expected <dir>/lef/$LIB_NAME.lef."
	exit 1
fi

rm -rf "$TARGET_DIR"
cp -r "${SRC_DIRS[0]%/}" "$TARGET_DIR"

# The archive stores files as 0600 and directories as 0500, which would leave
# the library unreadable for the container user and undeletable for later
# cleanup steps.
chmod -R u+w,a+rX "$TARGET_DIR"

echo "[INFO] EZ130 8T library installed to $TARGET_DIR"
