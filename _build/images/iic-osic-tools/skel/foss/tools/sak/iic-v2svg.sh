#!/bin/sh
# ========================================================================
# Verilog-to-SVG conversion script using Yosys and netlistsvg
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
# Usage: iic-v2svg.sh <input.v> <output.svg>
#
# This script uses Yosys (https://github.com/YosysHQ/yosys) and
# netlistsvg (https://github.com/nturley/netlistsvg).
# ========================================================================

ERR_NO_PARAM=1
ERR_CMD_NOT_FOUND=2
ERR_FILE_NOT_FOUND=3

if [ $# != 2 ]; then
	echo
	echo "Verilog-to-SVG conversion script using Yosys and netlistsvg (IIC@JKU)"
	echo
	echo "Usage: $0 <input.v> <output.svg>"
	echo
	exit $ERR_NO_PARAM
fi

if [ ! -x "$(command -v yosys)" ]; then
    	echo "[ERROR] Yosys could not be found!"
    	exit $ERR_CMD_NOT_FOUND
fi

if [ ! -x "$(command -v netlistsvg)" ]; then
    	echo "[ERROR] Netlistsvg could not be found!"
    	exit $ERR_CMD_NOT_FOUND
fi

if [ ! -f "$1" ]; then
	echo "[ERROR] File $1 not found!"
	exit $ERR_FILE_NOT_FOUND
fi

{
	echo "read_verilog $1"
	# opt is optional, makes nicer looking schematic
	echo "proc; opt"
	echo "write_json /tmp/$1.tmp"
} > "/tmp/$1.cmd"

# run conversion (Verilog to JSON via Yosys, JSON to SVG via netlistsvg)
echo "Start conversion..."

yosys -s "/tmp/$1.cmd" > /dev/null

if [ ! -f "/tmp/$1.cmd" ]; then
	echo "[ERROR] No yosys output file found, not sure what is going on!"
	exit $ERR_FILE_NOT_FOUND
fi

netlistsvg "/tmp/$1.tmp" -o "$2"

# cleanup
rm -f "/tmp/$1.cmd"
rm -f "/tmp/$1.tmp"

echo "[DONE] Bye!"
