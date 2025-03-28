#!/bin/sh
# ========================================================================
# Switch PDKs (for IIC-OSIC-TOOLS)
#
# SPDX-FileCopyrightText: 2023-2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
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
# Usage: iic-pdk <pdk> [<stdcell-lib>]
#
# ========================================================================

ERROR=0

# Print out usage
# ---------------

if [ $# = 0 ]; then

	echo
	echo "Switch PDKs"
	echo
	echo "Usage: iic-pdk <pdk> [<stdcell-lib>]"
	echo
	if [ -d "$PDK_ROOT" ]; then
		echo "Available PDKs:"
		# shellcheck disable=SC2010
		ls "$PDK_ROOT" | grep -v volare
		echo
	fi

else

	# check if PDK_ROOT is set, if not, set it to the default location 
	if [ -z ${PDK_ROOT+z} ]; then
		if [ -d /foss/pdks ]; then
			export PDK_ROOT /foss/pdks
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
		export KLAYOUT_PATH="$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech"
	else
		echo "[ERROR] PDK directory $PDK_ROOT/$1 not found!"
		ERROR=1
	fi

	if [ $# = 2 ]; then
		export STD_CELL_LIBRARY="$2"
	fi

	if [ $ERROR = 0 ]; then
		echo "PDK_ROOT=$PDK_ROOT"
		echo "PDK=$PDK"
		echo "PDKPATH=$PDKPATH"
		[ $# = 2 ] && echo "STD_CELL_LIBRARY=$STD_CELL_LIBRARY"	
		#echo
		#echo "[DONE] Bye!"
	fi

fi
