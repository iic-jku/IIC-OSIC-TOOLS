#!/bin/sh
# ========================================================================
# Verilog/SystemVerilog Linting helper script
#
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
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
# Usage: sak-vlint [-i|-v|-l|-e|-u|-y|-b|-a]
#        [-g1995|-g2001|-g2005|-g2005-sv|-g2009|-g2012]
#        <file.v>|<file.sv>
#
# The script runs linting on <file.v> or <file.sv>
# ========================================================================

ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_PROG_NOT_AVAILABLE=4

# print out usage
# ---------------

if [ $# = 0 ]; then
	echo
	echo "Verilog/SystemVerilog linting (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-i|-v|-l|-e|-u|-y|-b|-a] [-g1995|-g2001|-g2005|-g2005-sv|-g2009|-g2012] <file.v>|<file.sv>"
	echo "       -i Run <iverilog>"
	echo "       -v Run <verilator>"
	echo "       -l Run <slang>"
	echo "       -e Run <verible-verilog-lint>"
	echo "       -u Run <surelog>"
	echo "       -y Run <yosys>"
	echo "       -b Run <iverilog> followed by <verilator> (default)"
	echo "       -a Run all available linters"
	echo "       -g VERSION Sets the Verilog standard for <iverilog> (default 2005)"
	echo "       -d Enable debug information"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

RUN_ICARUS=0
RUN_VERILATOR=0
RUN_SLANG=0
RUN_VERIBLE=0
RUN_SURELOG=0
RUN_YOSYS=0
LINTER_SELECTED=0
VERILOG_VERSION=2005
VERSION_SET=0
DEBUG=0

# check flags
# -----------

while getopts "ivleuybag:d" flag; do
	case $flag in
		i)
			[ $DEBUG = 1 ] && echo "[INFO] flag -i is set"
			RUN_ICARUS=1
			LINTER_SELECTED=1
			;;
		v)
			[ $DEBUG = 1 ] && echo "[INFO] flag -v is set"
			RUN_VERILATOR=1
			LINTER_SELECTED=1
			;;
		l)
			[ $DEBUG = 1 ] && echo "[INFO] flag -l is set"
			RUN_SLANG=1
			LINTER_SELECTED=1
			;;
		e)
			[ $DEBUG = 1 ] && echo "[INFO] flag -e is set"
			RUN_VERIBLE=1
			LINTER_SELECTED=1
			;;
		u)
			[ $DEBUG = 1 ] && echo "[INFO] flag -u is set"
			RUN_SURELOG=1
			LINTER_SELECTED=1
			;;
		y)
			[ $DEBUG = 1 ] && echo "[INFO] flag -y is set"
			RUN_YOSYS=1
			LINTER_SELECTED=1
			;;
		b)
			[ $DEBUG = 1 ] && echo "[INFO] flag -b is set"
			RUN_ICARUS=1
			RUN_VERILATOR=1
			LINTER_SELECTED=1
			;;
		a)
			[ $DEBUG = 1 ] && echo "[INFO] flag -a is set"
			RUN_ICARUS=1
			RUN_VERILATOR=1
			RUN_SLANG=1
			RUN_VERIBLE=1
			RUN_SURELOG=1
			RUN_YOSYS=1
			LINTER_SELECTED=1
			;;
		g)
			[ $DEBUG = 1 ] && echo "[INFO] flag -g is set"
			VERILOG_VERSION=${OPTARG}
			VERSION_SET=1
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

# Check if file name was provided
# -------------------------------
if [ -z "$FILE_NAME" ]; then
	echo "[ERROR] No input file specified!"
	exit $ERR_NO_PARAM
fi

# Auto-detect standard based on file extension
# --------------------------------------------
if [ $VERSION_SET = 0 ]; then
	case "$FILE_NAME" in
		*.sv)
			VERILOG_VERSION=2012
			[ $DEBUG = 1 ] && echo "[INFO] .sv extension detected, setting -g2012"
			;;
		*.v)
			VERILOG_VERSION=2005
			[ $DEBUG = 1 ] && echo "[INFO] .v extension detected, setting -g2005"
			;;
	esac
fi

# Apply default linters if none explicitly selected
# -------------------------------------------------
if [ $LINTER_SELECTED = 0 ]; then
	RUN_ICARUS=1
	RUN_VERILATOR=1
fi

if [ $DEBUG = 1 ]; then
	echo "[INFO] RUN_ICARUS=$RUN_ICARUS"
	echo "[INFO] RUN_VERILATOR=$RUN_VERILATOR"
	echo "[INFO] RUN_SLANG=$RUN_SLANG"
	echo "[INFO] RUN_VERIBLE=$RUN_VERIBLE"
	echo "[INFO] RUN_SURELOG=$RUN_SURELOG"
	echo "[INFO] RUN_YOSYS=$RUN_YOSYS"
	echo "[INFO] VERILOG_VERSION=$VERILOG_VERSION"
	echo "[INFO] FILE_NAME=$FILE_NAME"
fi

# Check if the input file exists
# ------------------------------
if [ ! -f "$FILE_NAME" ]; then
	echo "[ERROR] File <$FILE_NAME> not found!"
	exit $ERR_FILE_NOT_FOUND
fi

# Run the linting
# ---------------

if [ $RUN_ICARUS = 1 ]; then
	if [ -x "$(command -v iverilog)" ]; then
		echo "[INFO] Run iverilog linting on $FILE_NAME..."
		iverilog -g"$VERILOG_VERSION" -tnull "$FILE_NAME"
	else
		echo "[WARNING] iverilog not available!"
	fi
fi

if [ $RUN_VERILATOR = 1 ]; then
	if [ -x "$(command -v verilator)" ]; then
		echo "[INFO] Run verilator linting on $FILE_NAME..."
		verilator --lint-only -Wall "$FILE_NAME"
	else
		echo "[WARNING] verilator not available!"
	fi
fi

if [ $RUN_SLANG = 1 ]; then
	if [ -x "$(command -v slang)" ]; then
		echo "[INFO] Run slang linting on $FILE_NAME..."
		slang --lint-only "$FILE_NAME"
	else
		echo "[WARNING] slang not available!"
	fi
fi

if [ $RUN_VERIBLE = 1 ]; then
	if [ -x "$(command -v verible-verilog-lint)" ]; then
		echo "[INFO] Run verible linting on $FILE_NAME..."
		verible-verilog-lint "$FILE_NAME"
	else
		echo "[WARNING] verible-verilog-lint not available!"
	fi
fi

if [ $RUN_SURELOG = 1 ]; then
	if [ -x "$(command -v surelog)" ]; then
		echo "[INFO] Run surelog linting on $FILE_NAME..."
		surelog -parseonly "$FILE_NAME"
	else
		echo "[WARNING] surelog not available!"
	fi
fi

if [ $RUN_YOSYS = 1 ]; then
	if [ -x "$(command -v yosys)" ]; then
		echo "[INFO] Run yosys linting on $FILE_NAME..."
		if [ "$VERILOG_VERSION" = "2012" ]; then
			yosys -q -p "read_verilog -sv $FILE_NAME"
		else
			yosys -q -p "read_verilog $FILE_NAME"
		fi
	else
		echo "[WARNING] yosys not available!"
	fi
fi

echo "[DONE] Bye!"
