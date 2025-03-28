#!/bin/sh
# ========================================================================
# GDS<>OASIS conversion script using KLayout
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
# Usage: iic-layconv.sh <input layout> <output layout>
#
# This script uses KLayout (https://www.klayout.de).
# ========================================================================

ERR_NO_PARAM=1
ERR_CMD_NOT_FOUND=2
ERR_FILE_NOT_FOUND=3
ERR_FILE_OVERWRITE=4

if [ $# = 0 ]; then
	echo
	echo "GDS2<>OASIS conversion script using KLayout (IIC@JKU)"
	echo
	echo "Usage: $0 [-d] [-z] <input layout> <output layout>"
	echo "       <input layout> can be GDS2 (.gds[.gz]) or OASIS (.oas[.gz]) (optionally gzipped)"
	echo "       <output layout> can be OASIS (.oas) or GDS2 (.gds)"
	echo "       -d Enable debug information"
	echo "       -z gzip output file after conversion"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

DEBUG=0
DO_ZIP=0

# check flags
# -----------

while getopts "dz" flag; do
	case $flag in
		d)
			echo "[INFO] DEBUG is enabled!"
			DEBUG=1
			;;
		z)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -z is set."
			if [ ! -x "$(command -v gzip)" ]; then
    			echo "[ERROR] gzip could not be found!"
    			exit $ERR_CMD_NOT_FOUND
			fi
			DO_ZIP=1
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# a bit of housekeeping and checks
# --------------------------------

if [ $# != 2 ]; then
	echo
	echo "[ERROR] Need exactly two operands (input and output file)!"
	echo
	exit $ERR_NO_PARAM
fi

if [ ! -x "$(command -v klayout)" ]; then
    	echo "[ERROR] KLayout could not be found!"
    	exit $ERR_CMD_NOT_FOUND
fi

if [ ! -x "$(command -v python3)" ]; then
    	echo "[ERROR] Python could not be found!"
    	exit $ERR_CMD_NOT_FOUND
fi



# do the file conversion
# ----------------------

FILE_IN=$(realpath "$1")
FILE_OUT=$(dirname "$FILE_IN")/"$2"
TMP_FILE=/tmp/conv_$(basename "$1").py

if [ ! -f "$FILE_IN" ]; then
	echo "[ERROR] File $1 not found!"
	exit $ERR_FILE_NOT_FOUND
fi

if [ -f "$FILE_OUT" ]; then
	echo "[ERROR] File $2 exists, would be overwritten!"
	exit $ERR_FILE_OVERWRITE
fi

{
	echo "import pya as k"
	echo "l = k.Layout()"
	echo "l.read(\"$FILE_IN\")"
	echo "l.write(\"$FILE_OUT\")"
	echo "exit()"
} > "$TMP_FILE"

# run conversion 
[ $DEBUG -eq 1 ] && echo "[INFO] Start conversion..."

python3 "$TMP_FILE"

if [ -f "$FILE_OUT.gz" ]; then
	echo "[ERROR] File $2.gz exists, would be overwritten!"
	exit $ERR_FILE_OVERWRITE
fi
[ $DO_ZIP -eq 1 ] && gzip "$FILE_OUT"

# cleanup
[ $DEBUG -eq 0 ] && rm -f "$TMP_FILE"

echo "[DONE] Bye!"
