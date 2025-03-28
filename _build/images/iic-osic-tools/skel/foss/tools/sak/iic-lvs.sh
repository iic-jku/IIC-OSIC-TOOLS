#!/bin/sh
# ========================================================================
# LVS (Layout-vs-Schematic) Script for Open-Source IC Design
#
# SPDX-FileCopyrightText: 2021-2023 Harald Pretl
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
# Usage: iic-lvs.sh [-d] [-w workdir] [-s <schematic> -l <layout> | <cellname>]
#
# The script can also compare a powered Verilog netlist named
# <cellname.v> to a layout.
#
# The LVS script can also compare a netlist created from a 
# Powered-Verilog-to-xschem-schematic conversion using iic-v2sch.
# ========================================================================

ERR_LVS_MISMATCH=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_NO_VAR=4
ERR_NO_RESULT=5
ERR_PDK_NOT_SUPPORTED=6
ERR_UNKNOWN_FILE=7

if [ $# -eq 0 ]; then
	echo
	echo "LVS script for netgen (IIC@JKU)"
	echo
	echo "Usage: $0 [-d] [-w <workdir>] [-s <schematic>|<netlist> -l <layout> -c <cellname> | <cellname>]"
	echo
	echo "       Specify <cellname> to use for schematic and layout, where default file"
	echo "       locations and name prefixes (.sch|.spice|.spc|.v|.mag|.mag.gz|.gds|.gds.gz)"
	echo "       are used. When no <cellname> is specified use -s, -l, and -c to point to the"
	echo "       corresponding files and name the topcell."
	echo
	echo "       -s Use this <schematic> (generated from xschem schematic or a SPICE netlist)"
	echo "       -l Use this <layout> view"
	echo "       -c Name of <topcell>"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -d Enable debug information"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

DEBUG=0
RESDIR=$PWD
CELLS_GIVEN=0

# check if PDK variables are properly set and the PDK is supported
# ----------------------------------------------------------------

if [ -z ${PDK_ROOT+x} ]; then
	echo "[ERROR] Variable PDK_ROOT not set!"
	exit $ERR_NO_VAR
fi

if [ -z ${PDK+x} ]; then
	echo "[ERROR] Variable PDK not set!"
	exit $ERR_NO_VAR
fi

if echo "$PDK" | grep -q -i "sky130"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] sky130 PDK selected."
elif echo "$PDK" | grep -q -i "gf180mcuC"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] gf180mcuC PDK selected."
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi

if [ -z ${STD_CELL_LIBRARY+x} ]; then
	echo "[ERROR] Variable STD_CELL_LIBRARY not set!"
	exit $ERR_NO_VAR
fi

# check flags
# -----------

while getopts "s:l:w:c:d" flag; do
	case $flag in
		w)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -w is set to <$OPTARG>."
			RESDIR=$(realpath "$OPTARG")
			;;
		s)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -s is set to <$OPTARG>."
			CELL_SCH=$(realpath "$OPTARG")
			if echo "$CELL_SCH" | grep -q -i "\.sch"; then
				VERILOG_MODE=0
				SPICE_MODE=0
			elif echo "$CELL_SCH" | grep -q -i "\.spice"; then
				VERILOG_MODE=0
				SPICE_MODE=1
			elif echo "$CELL_SCH" | grep -q -i "\.spc"; then
				VERILOG_MODE=0
				SPICE_MODE=1
			elif echo "$CELL_SCH" | grep -q -i "\.v"; then
				VERILOG_MODE=1
				SPICE_MODE=0
			else
				echo "[ERROR] Unknown file format of <$CELL_SCH>!"
				exit $ERR_UNKNOWN_FILE
			fi
			CELLS_GIVEN=1
			;;
		l)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -l is set to <$OPTARG>."
			CELL_LAY=$(realpath "$OPTARG")
			if echo "$CELL_LAY" | grep -q -i "\.gds"; then
				GDS_MODE=1
			elif echo "$CELL_LAY" | grep -q -i "\.mag"; then
				GDS_MODE=0
			else
				echo "[ERROR] Unknown file format of <$CELL_LAY>!"
				exit $ERR_UNKNOWN_FILE
			fi
			CELLS_GIVEN=1
			;;
		c)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -c is set to <$OPTARG>."
			TOPCELL=$OPTARG
			CELLS_GIVEN=1
			;;	
		d)
			echo "[INFO] DEBUG is enabled!"
			DEBUG=1
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# Check if all 3 parameters -s -l and -c are specified
# ----------------------------------------------------

if [ $CELLS_GIVEN -eq 1 ]; then
	if [ -z ${CELL_SCH+x} ]; then
	echo "[ERROR] Parameter -s not set! All 3 parameters (-s, -l, -c) are needed."
	exit $ERR_NO_VAR
	fi
	if [ -z ${CELL_LAY+x} ]; then
	echo "[ERROR] Parameter -l not set! All 3 parameters (-s, -l, -c) are needed."
	exit $ERR_NO_VAR
	fi
	if [ -z ${TOPCELL+x} ]; then
	echo "[ERROR] Parameter -c not set! All 3 parameters (-s, -l, -c) are needed."
	exit $ERR_NO_VAR
	fi
fi

# Check if files exist, look into usual directories
# -------------------------------------------------

if [ $CELLS_GIVEN -eq 1 ]; then
	if [ ! -f "$CELL_SCH" ]; then
		echo "[ERROR] File <$CELL_SCH> not found!"
		exit $ERR_FILE_NOT_FOUND
	fi

	if [ ! -f "$CELL_LAY" ]; then
		echo "[ERROR] File <$CELL_LAY> not found!"
		exit $ERR_FILE_NOT_FOUND
	fi
else
	TOPCELL=$1
	if [ -f "$1.v" ]; then
		CELL_V="$1.v"
		VERILOG_MODE=1
		SPICE_MODE=0
	else
		VERILOG_MODE=0
		if [ -f "$1.sch" ]; then
			CELL_SCH="$1.sch"
			SPICE_MODE=0
		elif [ -f "sch/$1.sch" ]; then
			CELL_SCH="sch/$1.sch"
			SPICE_MODE=0
		elif [ -f "xschem/$1.sch" ]; then
			CELL_SCH="xschem/$1.sch"
			SPICE_MODE=0
		elif [ -f "$1.spice" ]; then
			CELL_SCH="$1.spice"
			SPICE_MODE=1
		elif [ -f "$1.spc" ]; then
			CELL_SCH="$1.spc"
			SPICE_MODE=1
		else
			echo "[ERROR] No schematic/SPICE netlist/Verilog file found!"
			exit $ERR_FILE_NOT_FOUND
		fi
	fi

	if [ -f "$1.mag" ]; then
		CELL_LAY="$1.mag"
		GDS_MODE=0
	elif [ -f "$1.mag.gz" ]; then
		CELL_LAY="$1.mag.gz"
		GDS_MODE=0
	elif [ -f "$1.gds" ]; then
		CELL_LAY="$1.gds"
		GDS_MODE=1
	elif [ -f "$1.gds.gz" ]; then
		CELL_LAY="$1.gds.gz"
		GDS_MODE=1
	elif [ -f "lay/$1.mag" ]; then
		CELL_LAY="lay/$1.mag"
		GDS_MODE=0
	elif [ -f "lay/$1.mag.gz" ]; then
		CELL_LAY="lay/$1.mag.gz"
		GDS_MODE=0
	elif [ -f "lay/$1.gds" ]; then
		CELL_LAY="lay/$1.gds"
		GDS_MODE=1
	elif [ -f "lay/$1.gds.gz" ]; then
		CELL_LAY="lay/$1.gds.gz"
		GDS_MODE=1
	elif [ -f "mag/$1.mag" ]; then
		CELL_LAY="mag/$1.mag"
		GDS_MODE=0
	elif [ -f "mag/$1.mag.gz" ]; then
		CELL_LAY="mag/$1.mag.gz"
		GDS_MODE=0
	elif [ -f "gds/$1.gds" ]; then
		CELL_LAY="gds/$1.gds"
		GDS_MODE=1
	elif [ -f "gds/$1.gds.gz" ]; then
		CELL_LAY="gds/$1.gds.gz"
		GDS_MODE=1
	else
		echo "[ERROR] No layout file found!"
		exit $ERR_FILE_NOT_FOUND
	fi
fi

[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 1 ] && echo "[INFO] Using Verilog file <$CELL_V>."
[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 0 ]  && [ "$SPICE_MODE" -eq 0 ] && echo "[INFO] Using schematic file <$CELL_SCH>."
[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 0 ]  && [ "$SPICE_MODE" -eq 1 ] && echo "[INFO] Using SPICE netlist file <$CELL_SCH>."
[ $DEBUG -eq 1 ] && echo "[INFO] Using layout file <$CELL_LAY>."

# define useful variables
# -----------------------

FBASENAME=$(basename "$TOPCELL" | cut -d. -f1)
EXT_SCRIPT="$RESDIR/ext_$FBASENAME.tcl"
NETLIST_SCH="$RESDIR/$FBASENAME.sch.spc"
NETLIST_LAY="$RESDIR/$FBASENAME.ext.spc"
LVS_REPORT="$RESDIR/$FBASENAME.lvs.out"
LVS_LOG="$RESDIR/$FBASENAME.lvs.log"
[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"

# remove old netlists
# -------------------

[ -f "$NETLIST_SCH" ] && rm -f "$NETLIST_SCH"
[ -f "$NETLIST_LAY" ] && rm -f "$NETLIST_LAY"

# initial checks passed, start working
# ------------------------------------

if [ "$VERILOG_MODE" -eq 0 ]; then
	echo "[INFO] Running LVS of <$CELL_LAY> vs <$CELL_SCH>."
else
	echo "[INFO] Running LVS of <$CELL_LAY> vs <$CELL_V>."
fi

# extract the SPICE netlist from schematic
# ----------------------------------------

if [ "$VERILOG_MODE" -eq 0 ]; then
	if [ "$SPICE_MODE" -eq 0 ]; then
		echo "[INFO] Extracting netlist from schematic <$CELL_SCH>..."
		XSCHEMTCL="set lvs_netlist 1; set lvs_ignore 1; set netlist_dir $RESDIR"
		xschem --rcfile "$PDK_ROOT/$PDK/libs.tech/xschem/xschemrc" \
			-n -s -q --no_x \
			--tcl "$XSCHEMTCL" \
			"$CELL_SCH" \
			-N "$NETLIST_SCH" \
			> /dev/null 2> /dev/null

		if [ ! -f "$NETLIST_SCH" ]; then
			echo "[ERROR] No schematic netlist produced!"
			exit $ERR_NO_RESULT
		fi	

		# check if the schematic netlist contains standard cells: if yes, include the library with
		# SPICE netlists for the standard cells
		if grep -q "$STD_CELL_LIBRARY" "$NETLIST_SCH"; then
				# Remove the .end
				sed -i '/\.end\b/d' "$NETLIST_SCH"
				# Append sky130 lib
				cat "$PDK_ROOT/$PDK/libs.ref/$STD_CELL_LIBRARY/spice/$STD_CELL_LIBRARY.spice" >> "$NETLIST_SCH"
				# Add .end
				echo ".end" >> "$NETLIST_SCH"
		fi

		# remove .save statements from xschem (if there are any)
		sed -i '/.save/d' "$NETLIST_SCH"
	else
		echo "[INFO] Using SPICE netlist <$CELL_SCH>..."
		cp "$CELL_SCH" "$NETLIST_SCH" 
	fi
fi

# generate extract script for magic
# ---------------------------------
# the script is using code snippets from https://github.com/efabless/utilities/tree/main/LVS

{
	echo "crashbackups stop"
	echo "drc off"
} > "$EXT_SCRIPT"

if [ "$GDS_MODE" -eq 0 ]; then
	# we read a .mag/.mag.gz view
	{
		echo "load ${CELL_LAY}"
	} >> "$EXT_SCRIPT"
else
	# we read a .gds/.gds.gz view
	{
		echo "gds read $CELL_LAY"
		echo "load $TOPCELL"
	} >> "$EXT_SCRIPT"
fi

{
	echo "select top cell"
	echo "extract path $RESDIR"
	echo "extract no capacitance"
	echo "extract no coupling"
	echo "extract no resistance"
	echo "extract no length"
	echo "extract all"
	echo "ext2spice lvs"
} >> "$EXT_SCRIPT"

if [ "$VERILOG_MODE" -eq 1 ]; then
	# this is needed for the LVS in netgen because the standard cells
	# are not instantiated in the (powered) .v file
	echo "ext2spice subcircuit descend off"		>> "$EXT_SCRIPT"
fi

{
	echo "ext2spice -p $RESDIR -o $NETLIST_LAY"
	echo "quit -noprompt"
} >> "$EXT_SCRIPT"

# extract SPICE netlist from layout with magic
# --------------------------------------------

echo "[INFO] Extracting netlist from layout <$CELL_LAY>..."
OLDDIR=$PWD && cd "$RESDIR" || exit $ERR_NO_RESULT
magic -dnull -noconsole \
	-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
	 "$EXT_SCRIPT" \
	 > /dev/null 2> /dev/null
cd "$OLDDIR" || exit $ERR_NO_RESULT

if [ ! -f "$NETLIST_LAY" ]; then
	echo "[ERROR] No layout netlist produced!"
	exit $ERR_NO_RESULT
fi

# now run the LVS using netgen
# ----------------------------

echo "[INFO] Run netgen..."
if [ "$VERILOG_MODE" -eq 0 ]; then
	netgen -batch lvs "$NETLIST_LAY $TOPCELL" "$NETLIST_SCH $TOPCELL" \
		"$PDK_ROOT/$PDK/libs.tech/netgen/${PDK}_setup.tcl" \
		"$LVS_REPORT" > "$LVS_LOG"
else
	# this is not needed if subcircuit descend off is applied during the extract
	# UPDATE: still needed, the subcircuit descend off seems to not work
	export MAGIC_EXT_USE_GDS=1
	netgen -batch lvs "$NETLIST_LAY $TOPCELL" "$CELL_V $TOPCELL" \
                "$PDK_ROOT/$PDK/libs.tech/netgen/${PDK}_setup.tcl" \
                "$LVS_REPORT" > "$LVS_LOG"
fi

# finished
# --------

[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

echo "---"

if grep -i -q "Circuits match uniquely" "$LVS_REPORT"; then
	echo "CONGRATULATIONS! LVS is OK, schematic/netlist and layout match!"
	echo "---"
else
	echo "LVS ERRORS FOUND! Please check <$LVS_REPORT>!" 
	echo "---"
	exit $ERR_LVS_MISMATCH
fi
echo "[DONE] Bye!"
