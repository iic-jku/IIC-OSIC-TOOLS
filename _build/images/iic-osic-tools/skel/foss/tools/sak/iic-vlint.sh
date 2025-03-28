#!/bin/sh
# ========================================================================
# Verilog Linting helper script
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
# Usage: iic-vlint [-i|-v|-b] [-g1995|-g2001|-g2005|-g2005-sv|-g2009|-g2012]
#        <file.v>
#
# The script runs linting on <file.v>
# ========================================================================

ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_PROG_NOT_AVAILABLE=4

# print out usage
# ---------------

if [ $# = 0 ]; then
	echo
	echo "Verilog linting using Icarus Verilog and Verilator (IIC@JKU)"
	echo
	echo "Usage: $0 [-d] [-i|-v|-b] [-g1995|-g2001|-g2005|-g2005-sv|-g2009|-g2012] <file.v>"
	echo "       -i Run <iverilog>"
	echo "       -v Runs <verilator>"
	echo "       -b Run <iverilog> followed by <verilator> (default)"
	echo "       -g VERSION Sets the Verilog standard for <iverilog> (default 2005)"
	echo "       -d Enable debug information"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

RUN_ICARUS=1
RUN_VERILATOR=1
VERILOG_VERSION=2005
DEBUG=0

# check flags
# -----------

while getopts "ivbg:d" flag; do
	case $flag in
		i)
			[ $DEBUG = 1 ] && echo "[INFO] flag -i is set"
			RUN_ICARUS=1
			RUN_VERILATOR=0
			;;
		v)
			[ $DEBUG = 1 ] && echo "[INFO] flag -v is set"
			RUN_VERILATOR=1
			RUN_ICARUS=0
			;;
		b)
			[ $DEBUG = 1 ] && echo "[INFO] flag -b is set"
			RUN_ICARUS=1
			RUN_VERILATOR=1
			;;
		g)
			[ $DEBUG = 1 ] && echo "[INFO] flag -g is set"
			VERILOG_VERSION=${OPTARG}
			;;
		d)
			echo "[INFO] DEBUG is enabled"
			DEBUG=1
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

FILE_NAME=$1

if [ $DEBUG = 1 ]; then
	echo "[INFO] RUN_ICARUS=$RUN_ICARUS"
	echo "[INFO] RUN_VERILATOR=$RUN_VERILATOR"
	echo "[INFO] VERILOG_VERSION=$VERILOG_VERSION"
	echo "[INFO] FILE_NAME=$FILE_NAME"
fi

# Check if the input file exists
# ------------------------------
if [ ! -f "$FILE_NAME" ]; then
	echo "[ERROR] File $FILE_NAME not found!"
    exit $ERR_FILE_NOT_FOUND
fi

# Run the linting
# ---------------

if [ $RUN_ICARUS = 1 ]; then
	if [ -x "$(command -v iverilog)" ]; then
		echo "[INFO] Run iverilog linting on $FILE_NAME..."
		iverilog -g"$VERILOG_VERSION" -tnull "$FILE_NAME"
	else
		echo "[ERROR] iverilog not available!"
		exit $ERR_PROG_NOT_AVAILABLE
	fi
fi

if [ $RUN_VERILATOR = 1 ]; then
	if [ -x "$(command -v verilator)" ]; then
		echo "[INFO] Run verilator linting on $FILE_NAME..."
		verilator --lint-only -Wall "$FILE_NAME"
	else
		echo "[ERROR] verilator not available!"
		exit $ERR_PROG_NOT_AVAILABLE
	fi
fi

echo "[DONE] Bye!"
