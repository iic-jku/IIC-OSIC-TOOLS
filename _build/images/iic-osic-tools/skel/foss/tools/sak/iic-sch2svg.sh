#!/bin/sh
# ========================================================================
# Xschem SCH-to-SVG Converter (iic-sch2svg.sh)
#
# SPDX-FileCopyrightText: 2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
#
# Usage: iic-sch2svg.sh <schematic>
#
# The schematic with name <schematic> is converted to a SVG.
# ========================================================================

ERR_FILE_NOT_FOUND=1
ERR_NO_PARAM=2

if [ $# -eq 0 ]; then
	echo
	echo "SCH2SVG Converter (IIC@JKU)"
	echo
	echo "Usage: $0 <schematic>"
	echo
	echo "       Specify <schematic> to be converted to a SVG."
	echo
	exit $ERR_NO_PARAM
fi

# Check if file exists
# --------------------

if [ ! -f "$1" ]; then
	echo "[ERROR] File <$1> not found!"
	exit $ERR_FILE_NOT_FOUND
fi

# Define useful variables
# -----------------------

FBASENAME=$(basename "$1" | cut -d. -f1)
FPATH=$(dirname "$1")
SVGFILE="$FPATH/$FBASENAME.svg"

# Remove old SVG if it exists
# ---------------------------

[ -f "SVGFILE" ] && rm -f "$SVGFILE"

# Convert SCH to SVG
# ------------------
# See https://open-source-silicon.slack.com/archives/C017P3RAD42/p1724541254030279?thread_ts=1724517044.102669&cid=C017P3RAD42

xschem \
	--tcl "wm iconify ." \
	--command "xschem zoom_full; xschem toggle_colorscheme; xschem print svg $SVGFILE" \
	--quit "$1" \
	> /dev/null 2> /dev/null

# Finished
# --------

echo "[INFO] Schematic <$1> converted to <$SVGFILE>."
