#!/bin/sh
# ========================================================================
# DRC (Design Rule Check) Script for Open-Source IC Design
#
# SPDX-FileCopyrightText: 2021-2026 Harald Pretl
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
# Usage: sak-drc.sh [-d] [-m|-k|-b] [-c] [-f <pattern>] [-w workdir] <cellname>
#        -m  Run Magic DRC (default)
#        -k  Run KLayout DRC
#        -b  Run Magic and KLayout DRC
#        -c  Clean output files before running
#        -f  Set gds flatglob pattern for Magic (e.g., '*' to flatten all)
#        -w  Use <workdir> to store result files (default: current dir)
#        -d  Enable debug information
# ========================================================================

ERR_DRC=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_CMD_NOT_FOUND=4
ERR_UNKNOWN_FILE=5
ERR_PDK_NOT_SUPPORTED=6
ERR_NO_OUTPUT=7
ERR_NO_VAR=8

if [ $# -eq 0 ]; then
	echo
	echo "DRC script for Magic and KLayout (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-m|-k|-b] [-c] [-f <pattern>] [-w workdir] <cellname>"
	echo "       -m Run Magic DRC (default)"
	echo "       -k Run KLayout DRC"
	echo "       -b Run Magic and KLayout DRC"
	echo "       -c Clean output files"
	echo "       -f Set gds flatglob pattern for Magic (e.g., '*' to flatten all)"
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
FLATGLOB=""

# check that the PDK environment is set up
# ----------------------------------------

if [ -z "${PDKPATH+x}" ]; then
	echo "[ERROR] Variable PDKPATH not set!"
	exit $ERR_NO_VAR
fi

# check if the PDK is already supported by this script
# ----------------------------------------------------

if echo "$PDK" | grep -q -i "sky130"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] sky130 PDK selected."
elif echo "$PDK" | grep -q -i "gf180mcu"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] gf180mcu PDK selected."
elif echo "$PDK" | grep -q -i "ihp-sg13g2"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13g2 PDK selected"
elif echo "$PDK" | grep -q -i "ihp-sg13cmos5l"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13cmos5l PDK selected"
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi

# check flags
# -----------

while getopts "mkbcf:w:d" flag; do
	case $flag in
		f)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -f is set to <$OPTARG>."
			FLATGLOB="$OPTARG"
			;;
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
			# -m so a not-yet-existing (multi-level) workdir still resolves. It is created below.
			RESDIR=$(realpath -m "$OPTARG")
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
	rm -f  -- "$RESDIR"/*.magic.*.rpt "$RESDIR"/*.magic.*.log
	rm -f  -- "$RESDIR"/*.klayout.*.xml "$RESDIR"/*.klayout.*.log
	rm -rf -- "$RESDIR"/*.klayout.drc
fi

# define useful variables
# -----------------------

# strip only a known layout extension (if any) so cell names containing dots are preserved
FBASENAME=$(basename "$1")
case "$FBASENAME" in
	*.mag.gz)	FBASENAME=${FBASENAME%.mag.gz} ;;
	*.gds.gz)	FBASENAME=${FBASENAME%.gds.gz} ;;
	*.mag)		FBASENAME=${FBASENAME%.mag} ;;
	*.gds)		FBASENAME=${FBASENAME%.gds} ;;
esac
EXT_SCRIPT="$RESDIR/drc_$FBASENAME.tcl"
# GDS only: magic writes this marker if the GDS top cell is not named like the loaded cell; checked after the run.
CELL_MISMATCH_MARKER="$RESDIR/drc_$FBASENAME.cellmismatch"

# check if the input file exists
# ------------------------------

if [ -f "$1" ]; then
	# an exact file was given: accept it only if it has a known layout extension
	case "$1" in
		*.mag|*.mag.gz|*.gds|*.gds.gz)
			CELL_LAY="$1" ;;
		*)
			echo "[ERROR] Unsupported layout format <$1> (expected .mag, .mag.gz, .gds, .gds.gz)!"
			exit $ERR_UNKNOWN_FILE ;;
	esac
elif [ -f "$1.mag" ]; then
	CELL_LAY="$1.mag"
elif [ -f "$1.mag.gz" ]; then
	CELL_LAY="$1.mag.gz"
elif [ -f "$1.gds" ]; then
	CELL_LAY="$1.gds"
elif [ -f "$1.gds.gz" ]; then
	CELL_LAY="$1.gds.gz"
else
	echo "[ERROR] Layout <$1> not found!"
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

# KLayout DRC is implemented for sky130, gf180mcu, and ihp-sg13g2. For any other (already validated) PDK, skip KLayout: warn and continue if Magic DRC was also requested, otherwise there is nothing to check.
if [ $RUN_KLAYOUT -eq 1 ] && ! echo "$PDK" | grep -q -i -E "sky130|gf180mcu|ihp-sg13g2"; then
	if [ $RUN_MAGIC -eq 1 ]; then
		echo "[WARNING] KLayout DRC for $PDK not yet supported, running Magic DRC only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout DRC for $PDK not yet supported!"
		exit $ERR_PDK_NOT_SUPPORTED
	fi
fi

# KLayout can only read GDS, not a magic layout. Skip it for a .mag (warn if Magic also runs, error otherwise).
if [ $RUN_KLAYOUT -eq 1 ]; then
	case "$CELL_LAY" in
		*.mag|*.mag.gz)
			if [ $RUN_MAGIC -eq 1 ]; then
				echo "[WARNING] KLayout DRC needs a GDS layout, running Magic DRC only."
				RUN_KLAYOUT=0
			else
				echo "[ERROR] KLayout DRC needs a GDS layout (got <$CELL_LAY>)!"
				exit $ERR_UNKNOWN_FILE
			fi
			;;
	esac
fi

echo "[INFO] Results are put into <$RESDIR>."
# strip only a known layout extension so cell names containing dots are preserved
CELL_NAME=$(basename "$CELL_LAY")
case "$CELL_NAME" in
	*.mag.gz)	CELL_NAME=${CELL_NAME%.mag.gz} ;;
	*.gds.gz)	CELL_NAME=${CELL_NAME%.gds.gz} ;;
	*.mag)		CELL_NAME=${CELL_NAME%.mag} ;;
	*.gds)		CELL_NAME=${CELL_NAME%.gds} ;;
esac
# run dir holding the gf180mcu/ihp-sg13g2 KLayout DRC report(s) (.lyrdb)
KLAYOUT_RUNDIR="$RESDIR/${CELL_NAME}.klayout.drc"

# decompress gzipped layout views, magic cannot read them directly
# ----------------------------------------------------------------

GZ_TMP=""
case "$CELL_LAY" in
	*.gds.gz)
		GZ_TMP="$RESDIR/${CELL_NAME}.drctmp.gds"
		;;
	*.mag.gz)
		GZ_TMP="$RESDIR/${CELL_NAME}.drctmp.mag"
		;;
esac
if [ -n "$GZ_TMP" ]; then
	[ $DEBUG -eq 1 ] && echo "[INFO] Decompressing <$CELL_LAY> to <$GZ_TMP>."
	gunzip -c "$CELL_LAY" > "$GZ_TMP"
	CELL_LAY="$GZ_TMP"
fi

# launch Magic DRC
# ----------------

if [ $RUN_MAGIC -eq 1 ]; then
	echo "[INFO] Launching Magic DRC..."

	# remove old result files
	rm -f "$RESDIR/$CELL_NAME.magic.drc.rpt"
	# drop any stale marker so it only reflects this run
	rm -f "$CELL_MISMATCH_MARKER"

	# generate DRC script for Magic. match the extension only, not an occurrence in the path
	case "$CELL_LAY" in
		*.mag)
			[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on .mag file."
			{
				echo "crashbackups stop"
				echo "load $CELL_LAY"
			} > "$EXT_SCRIPT"
			;;
		*.gds)
			[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on .gds file."
			{
				echo "crashbackups stop"
				[ -n "$FLATGLOB" ] && echo "gds flatglob $FLATGLOB"
				echo "gds read $CELL_LAY"
				# Magic loads the cell named $CELL_NAME. If the GDS has no such top cell it would load an empty cell and report DRC clean. Detect that, record the real top cells, and quit.
				echo "if {[lsearch [cellname list topcells] {${CELL_NAME}}] < 0} {"
				echo "    set _fp [open {${CELL_MISMATCH_MARKER}} w]"
				echo "    puts \$_fp [cellname list topcells]"
				echo "    close \$_fp"
				echo "    quit -noprompt"
				echo "}"
				echo "load $CELL_NAME"
			} > "$EXT_SCRIPT"
			;;
		*)
			echo "[ERROR] Unknown file format for Magic DRC!"
			exit $ERR_UNKNOWN_FILE
			;;
	esac
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
		> "$RESDIR/$CELL_NAME.magic.drc.log" 2>&1 &
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
			> "$RESDIR/$CELL_NAME.klayout.drc.feol.log" 2>&1 &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd feol=false \
			-rd beol=true \
			-rd offgrid=false \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.beol.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/${PDK}_mr.drc" \
			> "$RESDIR/$CELL_NAME.klayout.drc.beol.log" 2>&1 &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.density.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/met_min_ca_density.lydrc" \
			> "$RESDIR/$CELL_NAME.klayout.drc.density.log" 2>&1 &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd threads="$(nproc --ignore 5)" \
			-rd flat_mode=true \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/pin_label_purposes_overlapping_drawing.rb.drc" \
			> "$RESDIR/$CELL_NAME.klayout.drc.pincheck.log" 2>&1 &

		klayout -b \
			-rd input="$CELL_LAY" \
			-rd report="$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" \
			-r "$PDKPATH/libs.tech/klayout/drc/zeroarea.rb.drc" \
			> "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.log" 2>&1 &
	elif echo "$PDK" | grep -q -i "gf180mcu"; then
		# gf180mcu via its gf180mcu.drc deck (run directly). variant=D selects the gf180mcuD stack (metal_top=11K, metal_level=5LM, mim_option=B). run_mode must be set explicitly (the deck aborts on an unknown mode), flat is the gf180 default.
		# The RDB report is written into the run dir so the shared evaluation below picks it up.
		rm -rf "$KLAYOUT_RUNDIR"
		mkdir -p "$KLAYOUT_RUNDIR"
		klayout -b \
			-rd input="$CELL_LAY" \
			-rd topcell="$CELL_NAME" \
			-rd variant=D \
			-rd run_mode=flat \
			-rd threads="$(nproc --ignore 5)" \
			-rd report="$KLAYOUT_RUNDIR/$CELL_NAME.lyrdb" \
			-r "$PDKPATH/libs.tech/klayout/tech/drc/gf180mcu.drc" \
			> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log" 2>&1 &
	elif echo "$PDK" | grep -q -i "ihp-sg13g2"; then
		# ihp-sg13g2 via its run_drc.py wrapper. It writes <layout>_<topcell>_<tables>.lyrdb (multiple reports are merged into a *_full.lyrdb) into --run_dir.
		# Scope (per the ICD reference flow): --no_feol --no_density --disable_extra_rules skips FEOL, density, and the extra "maximal" rule set for a faster run.
		rm -rf "$KLAYOUT_RUNDIR"
		mkdir -p "$KLAYOUT_RUNDIR"
		python3 "$PDKPATH/libs.tech/klayout/tech/drc/run_drc.py" \
			--path="$CELL_LAY" \
			--topcell="$CELL_NAME" \
			--run_dir="$KLAYOUT_RUNDIR" \
			--no_feol \
			--no_density \
			--disable_extra_rules \
			--mp="$(nproc --ignore 5)" \
			--density_thr="$(nproc --ignore 5)" \
			> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log" 2>&1 &
	fi
fi

# wait for all runs to finish
# ---------------------------

wait
echo "---"

# the decompressed layout is no longer needed after the DRC runs
[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"

# evaluate results of runs
# ------------------------

if [ $RUN_MAGIC -eq 1 ]; then
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

	# GDS top cell did not match the loaded cell name (marker written by magic above): report the specific cause instead of the generic error below.
	if [ -f "$CELL_MISMATCH_MARKER" ]; then
		echo "[ERROR] GDS top cell does not match <$CELL_NAME>!"
		echo "[ERROR] GDS top cell(s) found: <$(cat "$CELL_MISMATCH_MARKER")>."
		echo "[ERROR] Rename the layout file/cell so they match, then re-run."
		rm -f "$CELL_MISMATCH_MARKER"
		exit $ERR_NO_OUTPUT
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.magic.drc.rpt" ]; then
		echo "[ERROR] Magic DRC produced no report, see <$RESDIR/$CELL_NAME.magic.drc.log>!"
		exit $ERR_NO_OUTPUT
	fi

	if grep -q "COUNT: 0" "$RESDIR/$CELL_NAME.magic.drc.rpt"; then
		echo "[INFO] Magic DRC is clean!"
	else
		echo "[INFO] Magic DRC errors found! Check <$CELL_NAME.magic.drc.rpt>!"
		DRC_CLEAN=0	
	fi
fi

if [ $RUN_KLAYOUT -eq 1 ] && echo "$PDK" | grep -q -i "sky130"; then

	# each KLayout report violation is one <item> regardless of its geometry type (edge-pair, polygon, edge, ...), so count <item> rather than a single type.
	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.feol.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	DRC_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.feol.xml")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$CELL_NAME.klayout.drc.feol.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout FEOL DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.beol.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	DRC_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.beol.xml")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$CELL_NAME.klayout.drc.beol.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout BEOL DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.density.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	DENSITY_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.density.xml")
	if [ "$DENSITY_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DENSITY_ERRORS density errors found! Check <$CELL_NAME.klayout.drc.density.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout metal density DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	PINCHECK_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml")
	if [ "$PINCHECK_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $PINCHECK_ERRORS pin errors found! Check <$CELL_NAME.klayout.drc.pincheck.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout pin check DRC is clean!"
	fi

	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	ZEROAREA_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml")
	if [ "$ZEROAREA_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $ZEROAREA_ERRORS zero-area errors found! Check <$CELL_NAME.klayout.drc.zeroarea.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout zero-area DRC is clean!"
	fi
elif [ $RUN_KLAYOUT -eq 1 ]; then
	# gf180mcu / ihp-sg13g2 write their .lyrdb report(s) into the run dir. No report means the run itself failed (a DRC run with violations still writes a report); the reason is in the log.
	if ! find "$KLAYOUT_RUNDIR" -name '*.lyrdb' 2>/dev/null | grep -q .; then
		echo "[ERROR] KLayout DRC run failed (no report produced), see <$KLAYOUT_RUNDIR/$CELL_NAME.drc.log>!"
		exit $ERR_NO_OUTPUT
	fi
	# one violation is one <item> in the RDB report, regardless of geometry type
	DRC_ERRORS=$(find "$KLAYOUT_RUNDIR" -name '*.lyrdb' -exec cat {} + 2>/dev/null | grep -c "<item>")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$KLAYOUT_RUNDIR>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout DRC is clean!"
	fi
fi

echo "---"

if [ "$DRC_CLEAN" -eq 1 ]; then
		echo "CONGRATULATIONS! No DRC errors in <$CELL_NAME> found!"
		echo "---"
else
		echo "DRC ERRORS FOUND! Please check the output files!"
		echo "---"
		exit $ERR_DRC
fi

echo "[DONE] Bye!"
