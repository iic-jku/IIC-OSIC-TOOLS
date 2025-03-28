#!/bin/sh
# ========================================================================
# CHIP_ART Usage Script (optimized for IIC-OSIC-TOOLS)
#
# SPDX-FileCopyrightText: 2022-2023 Harald Pretl
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
# Usage: iic-chipart.sh [parameter list]
#
# This script provides a wrapper for the CHIP_ART package from GitHub at
# https://github.com/AUCOHL/DFFRAM
# ========================================================================

ERR_NO_VAR=1
ERR_NO_CHIPART=2
ERR_NO_INPUTFILE=3

export NO_CHECK_INSTALL=1

if [ -z ${PDK_ROOT+x} ]; then
	echo "[ERROR] Environment variable PDK_ROOT not set!"
	exit $ERR_NO_VAR
fi

if [ -z ${OPENLANE_ROOT+x} ]; then
	echo "[ERROR] Environment variable OPENLANE_ROOT not set!"
	exit $ERR_NO_VAR
fi

if [ ! -f chip_art.py ]; then
	echo "[ERROR] Script needs to be started in CHIP_ART directory!"
	echo
	echo "[INFO] You can install CHIP_ART using <iic-chipart-install.sh>."
	exit $ERR_NO_CHIPART
fi

if [ $# = 0 ]; then
	echo
	echo "Chipart wrapper script (IIC@JKU)"
	echo
	echo "Usage: $0 <image> <width>"
	echo
	echo "       <image> = name of graphics file"
	echo "       <width> = width of generated GDS logo in microns"
	echo
	exit $ERR_NO_VAR
else
	if [ ! -f "$1" ]; then
		echo "[ERROR] File $1 not found!"
		exit $ERR_NO_INPUTFILE
	fi
	make clean && make GDS_WIDTH="$2" IMAGE="$1"
fi

echo "[DONE] Chipart conversion done, bye!"
