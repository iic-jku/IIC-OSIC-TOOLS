#!/bin/sh
# ========================================================================
# Switch PDKs (for IIC-OSIC-TOOLS)
#
# SPDX-FileCopyrightText: 2023-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
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
# Usage: sak-pdk <pdk> [<stdcell-lib>]
#
# ========================================================================

ERROR=0

# Print out usage
# ---------------

if [ $# = 0 ]; then
	# present help
	echo "Usage: sak-pdk <pdk> [<stdcell-lib>]"
	echo
	if [ -d "$PDK_ROOT" ]; then
		echo "Available PDKs:"
		# shellcheck disable=SC2010
		ls "$PDK_ROOT" | grep -v ciel
		echo
	fi
else
	# check if PDK_ROOT is set, if not, set it to the default location 
	if [ -z "$PDK_ROOT" ]; then
		if [ -d /foss/pdks ]; then
			export PDK_ROOT="/foss/pdks"
		else
			echo "[ERROR] Variable PDK_ROOT is not set, and default location (/foss/pdks) not found!"
			ERROR=1
		fi
	fi

	# set PDK variables
	if [ -d "$PDK_ROOT/$1" ]; then
		export PDK="$1"
		export PDKPATH="$PDK_ROOT/$PDK"
		export SPICE_USERINIT_DIR="$PDK_ROOT/$PDK/libs.tech/ngspice"
		export KLAYOUT_PATH="/headless/.klayout:$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech"
	else
		echo "[ERROR] PDK directory $PDK_ROOT/$1 not found!"
		ERROR=1
	fi

	if [ $# = 2 ]; then
		export STD_CELL_LIBRARY="$2"
	else
		case "$1" in
			sky130A|sky130B)
				export STD_CELL_LIBRARY="sky130_fd_sc_hd"
				;;
			ihp-sg13g2)
				export STD_CELL_LIBRARY="sg13g2_stdcell"
				;;
			gf180mcuC|gf180mcuD)
				export STD_CELL_LIBRARY="gf180mcu_fd_sc_mcu7t5v0"
				;;
			*)
				echo "[ERROR] No valid standard cell library selected!"
				export STD_CELL_LIBRARY=""
				;;
		esac
	fi

	if [ $ERROR = 0 ]; then
		echo "PDK_ROOT=$PDK_ROOT"
		echo "PDK=$PDK"
		echo "PDKPATH=$PDKPATH"
		echo "STD_CELL_LIBRARY=$STD_CELL_LIBRARY"	
		echo "SPICE_USERINIT_DIR=$SPICE_USERINIT_DIR"
		echo "KLAYOUT_PATH=$KLAYOUT_PATH"
	fi
fi
