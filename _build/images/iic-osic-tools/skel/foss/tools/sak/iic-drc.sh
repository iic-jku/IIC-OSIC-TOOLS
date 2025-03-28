#!/bin/sh
# ========================================================================
# DRC (Design Rule Check) Script for Open-Source IC Design
#
# SPDX-FileCopyrightText: 2021-2024 Harald Pretl
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
# Usage: iic-drc.sh [-d] [-m|-k|-b] [-c] [-w workdir] <cellname>
# ========================================================================

ERR_DRC=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_CMD_NOT_FOUND=4
ERR_UNKNOWN_FILE=5
ERR_PDK_NOT_SUPPORTED=6
ERR_NO_OUTPUT=7

if [ $# -eq 0 ]; then
	echo
	echo "DRC script for Magic-VLSI and KLayout (IIC@JKU)"
	echo
	echo "Usage: $0 [-d] [-m|-k|-b] [-c] [-w workdir] <cellname>"
	echo "       -m Run Magic DRC (default)"
	echo "       -k Run KLayout DRC"
	echo "       -b Run Magic and KLayout DRC"
	echo "       -c Clean output files"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -d Enable debug information"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

RUN_MAGIC=1
RUN_KLAYOUT=0
RUN_CLEAN=0
DEBUG=0
DRC_CLEAN=1
RESDIR=$PWD

# check if the PDK is already supported by this script
# ----------------------------------------------------

if echo "$PDK" | grep -q -i "sky130"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] sky130 PDK selected."
elif echo "$PDK" | grep -q -i "gf180mcuC"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] gf180mcuC PDK selected."
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi

# check flags
# -----------

while getopts "mkbcw:d" flag; do
	case $flag in
		m)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -m is set."
			RUN_MAGIC=1
			RUN_KLAYOUT=0
			;;
		k)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -k is set."
			RUN_MAGIC=0
			RUN_KLAYOUT=1
			;;
		b)	
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -b is set."
			RUN_MAGIC=1
			RUN_KLAYOUT=1
			;;
		c)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -c is set."
			RUN_CLEAN=1
			;;
		w)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -w is set to <$OPTARG>."
			RESDIR=$(realpath "$OPTARG")
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

[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"
if [ $RUN_CLEAN -eq 1 ]; then
	rm -- -f "$RESDIR"/*.magic.*.rpt
	rm -- -f "$RESDIR"/*.klayout.*.xml
fi 

# define useful variables
# -----------------------

FBASENAME=$(basename "$1" | cut -d. -f1)
EXT_SCRIPT="$RESDIR/drc_$FBASENAME.tcl"

# check if the input file exists
# ------------------------------

if [ -f "$1" ]; then
	CELL_LAY="$1"
elif [ -f "$1.mag" ]; then
	CELL_LAY="$1.mag"
elif [ -f "$1.mag.gz" ]; then
	CELL_LAY="$1.mag.gz"
elif [ -f "$1.gds" ]; then
	CELL_LAY="$1.gds"
elif [ -f "$1.gds.gz" ]; then
	CELL_LAY="$1.gds.gz"
else
	echo "[ERROR] Layout <$CELL_LAY> not found!"
    exit $ERR_FILE_NOT_FOUND
fi

[ $DEBUG -eq 1 ] && echo "[INFO] CELL_LAY=$CELL_LAY"

# check if commands exist in the path
# -----------------------------------

if [ $RUN_MAGIC -eq 1 ]; then
	if [ ! -x "$(command -v magic)" ]; then
    	echo "[ERROR] Magic executable could not be found!"
    	exit $ERR_CMD_NOT_FOUND
	fi
fi

if [ $RUN_KLAYOUT -eq 1 ]; then
	if [ ! -x "$(command -v klayout)" ]; then
    	echo "[ERROR] KLayout executable could not be found!"
    	exit $ERR_CMD_NOT_FOUND
	fi
fi

echo "[INFO] Results are put into <$RESDIR>."
CELL_NAME=$(basename "$CELL_LAY" | cut -d. -f1)

# launch Magic DRC
# ----------------

if [ $RUN_MAGIC -eq 1 ]; then
	echo "[INFO] Launching Magic DRC..."

	# remove old result files
	rm -f "$RESDIR/$CELL_NAME.magic.drc.rpt"

	# generate DRC script for Magic
	if echo "$CELL_LAY" | grep -q -i "\.mag"; then
		[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on .mag file."
		{
			echo "crashbackups stop"
			echo "load $CELL_LAY"
		} > "$EXT_SCRIPT"
	elif echo "$CELL_LAY" | grep -q -i "\.gds"; then
		[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on .gds file."
		{
			echo "crashbackups stop"	
			echo "gds read $CELL_LAY"
			echo "load $CELL_NAME"
		} > "$EXT_SCRIPT"
	else
		echo "[ERROR] Unknown file format for Magic DRC!"
		exit $ERR_UNKNOWN_FILE
	fi
	{
		echo "set drc_rpt_path $RESDIR/$CELL_NAME.magic.drc.rpt"
		# shellcheck disable=SC2016
		echo 'set fout [open $drc_rpt_path w]'
		echo 'set oscale [cif scale out]'
		echo "set cell_name $CELL_NAME"

		echo 'select top cell'
		echo 'drc euclidean on'
		echo 'drc style drc(full)'
		echo 'drc check'
		echo 'set drcresult [drc listall why]'

		echo 'set count 0'
		# shellcheck disable=SC2016
		echo 'puts $fout "$cell_name"'
		# shellcheck disable=SC2016
		echo 'puts $fout "----------------------------------------"'
		# shellcheck disable=SC2016
		echo 'foreach {errtype coordlist} $drcresult {'
		# shellcheck disable=SC2016
		echo '  puts $fout $errtype'
		# shellcheck disable=SC2016
		echo '  puts $fout "----------------------------------------"'
		# shellcheck disable=SC2016
		echo '  foreach coord $coordlist {'
		# shellcheck disable=SC2016
		echo '    set bllx [expr {$oscale * [lindex $coord 0]}]'
		# shellcheck disable=SC2016
		echo '    set blly [expr {$oscale * [lindex $coord 1]}]'
		# shellcheck disable=SC2016
		echo '    set burx [expr {$oscale * [lindex $coord 2]}]'
		# shellcheck disable=SC2016
		echo '    set bury [expr {$oscale * [lindex $coord 3]}]'
		# shellcheck disable=SC2016
		echo '    set coords [format " %.3fum %.3fum %.3fum %.3fum" $bllx $blly $burx $bury]'
		# shellcheck disable=SC2016
		echo '    puts $fout "$coords"'
		# shellcheck disable=SC2016
		echo '    set count [expr {$count + 1} ]'
		echo '  }'
		# shellcheck disable=SC2016
		echo '  puts $fout "----------------------------------------"'
		echo '}'
		# shellcheck disable=SC2016
		echo 'puts $fout "\[INFO\] COUNT: $count"'
		# shellcheck disable=SC2016
		echo 'puts $fout "\[INFO\] Should be divided by 3 or 4"'
		# shellcheck disable=SC2016
		echo 'puts $fout ""'
		# shellcheck disable=SC2016
		echo 'close $fout'
		# shellcheck disable=SC2016
		#echo 'puts stdout "$count DRC errors found! (should be divided by 3 or 4)"'
		echo 'quit -noprompt'
	} >> "$EXT_SCRIPT"

	# run it 
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT" \
		> /dev/null 2> /dev/null &
fi

# launch KLayout DRC
# ------------------

if [ $RUN_KLAYOUT -eq 1 ]; then
	echo "[INFO] Launching KLayout DRC..."

	# remove old result files
	rm -f "$RESDIR/$CELL_NAME".klayout.*.xml

	[ $DEBUG -eq 1 ] && echo "[INFO] CELL_LAY=$CELL_LAY RESDIR=$RESDIR PDKPATH=$PDKPATH PDK=$PDK"

	if echo "$PDK" | grep -q -i "sky130"; then
		klayout -b \
			-rd input="$CELL_LAY" \
			-rd feol=true \
			-rd beol=false \
			-rd offgrid=true \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.feol.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/${PDK}_mr.drc" \
			> /dev/null 2> /dev/null &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd feol=false \
			-rd beol=true \
			-rd offgrid=false \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.beol.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/${PDK}_mr.drc" \
			> /dev/null 2> /dev/null &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.density.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/met_min_ca_density.lydrc" \
			> /dev/null 2> /dev/null &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd threads="$(nproc --ignore 5)" \
			-rd flat_mode=true \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/pin_label_purposes_overlapping_drawing.rb.drc" \
			> /dev/null 2> /dev/null &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/zeroarea.rb.drc" \
			> /dev/null 2> /dev/null &
	fi

	if echo "$PDK" | grep -q -i "gf180mcuC"; then
		echo "[ERROR] KLayout DRC for $PDK not yet supported!"
		exit $ERR_PDK_NOT_SUPPORTED
	fi	
fi

# wait for all runs to finish
# ---------------------------

wait
echo "---"

# evaluate results of runs
# ------------------------

if [ $RUN_MAGIC -eq 1 ]; then
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

	if [ ! -f "$RESDIR/$CELL_NAME.magic.drc.rpt" ]; then
		echo "[ERROR] No magic output found!"
		exit $ERR_NO_OUTPUT
	fi

	if grep -q "COUNT: 0" "$RESDIR/$CELL_NAME.magic.drc.rpt"; then
		echo "[INFO] Magic DRC is clean!"
	else
		echo "[INFO] Magic DRC errors found! Check <$CELL_NAME.magic.drc.rpt>!"
		DRC_CLEAN=0	
	fi
fi

if [ $RUN_KLAYOUT -eq 1 ]; then

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.feol.xml" ]; then
		echo "[ERROR] No klayout output found!"
		exit $ERR_NO_OUTPUT
	fi
	DRC_ERRORS=$(grep -c "edge-pair" "$RESDIR/$CELL_NAME.klayout.drc.feol.xml")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$CELL_NAME.klayout.drc.feol.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout FEOL DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.beol.xml" ]; then
		echo "[ERROR] No klayout output found!"
		exit $ERR_NO_OUTPUT
	fi
	DRC_ERRORS=$(grep -c "edge-pair" "$RESDIR/$CELL_NAME.klayout.drc.beol.xml")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$CELL_NAME.klayout.drc.beol.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout BEOL DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.density.xml" ]; then
		echo "[ERROR] No klayout output found!"
		exit $ERR_NO_OUTPUT
	fi
	DENSITY_ERRORS=$(grep -c "edge-pair" "$RESDIR/$CELL_NAME.klayout.drc.density.xml")
	if [ "$DENSITY_ERRORS" -ne 0 ]; then
		echo "[INFO] Klayout $DENSITY_ERRORS density errors found! Check <$CELL_NAME.klayout.drc.density.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout metal density DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" ]; then
		echo "[ERROR] No klayout output found!"
		exit $ERR_NO_OUTPUT
	fi
	PINCHECK_ERRORS=$(grep -c "edge-pair" "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml")
	if [ "$PINCHECK_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $PINCHECK_ERRORS pin errors found! Check <$CELL_NAME.klayout.drc.pincheck.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout pin check DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" ]; then
		echo "[ERROR] No klayout output found!"
		exit $ERR_NO_OUTPUT
	fi
	ZEROAREA_ERRORS=$(grep -c "edge-pair" "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml")
	if [ "$ZEROAREA_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $ZEROAREA_ERRORS zero-area errors found! Check <$CELL_LAY.klayout.drc.zeroarea.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout zero-area DRC is clean!"
	fi
fi

echo "---"

if [ "$DRC_CLEAN" -eq 1 ]; then
		echo "CONGRATULATIONS! No DRC errors in <$CELL_LAY> found!"
		echo "---"
else
		echo "DRC ERRORS FOUND! Please check the output files!"
		echo "---"
		exit $ERR_DRC
fi

echo "[DONE] Bye!"
