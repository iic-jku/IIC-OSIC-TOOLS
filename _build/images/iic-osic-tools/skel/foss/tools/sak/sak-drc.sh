#!/bin/sh
# ========================================================================
# DRC (Design Rule Check) Script for Open-Source IC Design
#
# SPDX-FileCopyrightText: 2021-2026 Harald Pretl, Simon Dorrer
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
# Usage: sak-drc.sh [-d] [-m|-k|-b] [-c] [-l <level>] [-j <n>] [-f <pattern>] [-w <workdir>] <cellname>
#        -m  Run Magic DRC (default)
#        -k  Run KLayout DRC
#        -b  Run Magic and KLayout DRC
#        -c  Clean output files before running
#        -l  KLayout DRC level: precheck|macro|regular (default: macro)
#        -j  Run at most <n> KLayout processes at once (default: 4, or the CPU count if lower)
#        -f  Set GDS flatglob pattern for Magic (e.g. '*' to flatten all)
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
	echo "Usage: $0 [-d] [-m|-k|-b] [-c] [-l <level>] [-j <n>] [-f <pattern>] [-w <workdir>] <cellname>"
	echo
	echo "       -m Run Magic DRC (default)"
	echo "       -k Run KLayout DRC"
	echo "       -b Run Magic and KLayout DRC"
	echo "       -c Clean output files before running"
	echo "       -l KLayout DRC level: precheck|macro|regular (default: macro)"
	echo "          precheck: core FEOL and BEOL rules only"
	echo "          macro: adds off-grid, pin, and zero-area checks, skips chip-level density and antenna"
	echo "          regular: all checks"
	echo "       -j Run at most <n> KLayout processes at once (default: 4, or the CPU count if lower)"
	echo "          without -j the sky130 decks all start at once"
	echo "          values above 4 only pay off for large layouts (e.g. 8 to 16 for a chip on a server),"
	echo "          every KLayout process needs about 0.5 GiB RAM plus the layout"
	echo "       -f Set GDS flatglob pattern for Magic (e.g. '*' to flatten all)"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -d Enable debug information"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

DEBUG=0
RESDIR=$PWD
RUN_MAGIC=1
RUN_KLAYOUT=0
RUN_CLEAN=0
FLATGLOB=""
DRC_LEVEL="macro"
JOBS=""
JOBS_SET=0

# check flags
# -----------

while getopts "mkbcl:j:f:w:d" flag; do
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
		l)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -l is set to <$OPTARG>."
			DRC_LEVEL="$OPTARG"
			;;
		j)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -j is set to <$OPTARG>."
			JOBS="$OPTARG"
			JOBS_SET=1
			;;
		f)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -f is set to <$OPTARG>."
			FLATGLOB="$OPTARG"
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

# check that the KLayout DRC level is valid
# -----------------------------------------

case "$DRC_LEVEL" in
	precheck|macro|regular) ;;
	*)
		echo "[ERROR] Unknown KLayout DRC level <$DRC_LEVEL> (expected precheck, macro, or regular)!"
		exit $ERR_NO_PARAM ;;
esac

# check the KLayout process limit (-j), the default is 4 or the CPU count if lower
# --------------------------------------------------------------------------------

# What more processes bring, measured on a 32-thread server (layouts from 0.012 mm2 to a 4 mm2 SoC, details in the pull request that added -j):
# - ihp regular: the 4 parts (main, extra rules, density, antenna) in parallel are 1.2x to 2.8x faster than one after another. Above 4 only one layout gained (a 1.5 mm2 chip, 22 % at -j 8), elsewhere the extra-rules deck sets the time and it cannot be split.
# - ihp precheck/macro: above 4 the rule deck is split into its tables, one process each. Small and medium cells get up to 4x slower, layouts whose single run takes minutes get 1.4x to 2x faster at -j 8 and another 20 % to 25 % at -j 32.
# - gf180mcu: one process with <n> threads. 4 threads are 8 % to 14 % faster than 1, 8 threads help at macro only, 32 threads are slower than 4.
# - sky130: every deck is its own process (2 to 5 by level), the pin check gains nothing from threads.
# Every KLayout process needs about 0.5 GiB RAM plus the layout: -j 4 took 0.6 GiB to 9 GiB, -j 32 took 17 GiB to 22 GiB. So -j 8 to 16 suits a large chip on a server with RAM to spare, -j 1 a batch of small cells.
if [ "$JOBS_SET" -eq 1 ]; then
	case "$JOBS" in
		''|*[!0-9]*|0*)
			echo "[ERROR] -j expects a positive integer (got <$JOBS>)!"
			exit $ERR_NO_PARAM ;;
	esac
else
	JOBS=$(nproc 2>/dev/null || echo 1)
	[ "$JOBS" -gt 4 ] && JOBS=4
fi
[ $DEBUG -eq 1 ] && echo "[INFO] KLayout DRC runs at most $JOBS processes at once."

# check that the PDK environment is set up
# ----------------------------------------

if [ -z "$PDK_ROOT" ]; then
	echo "[ERROR] Variable PDK_ROOT not set!"
	exit $ERR_NO_VAR
fi
if [ -z "$PDK" ]; then
	echo "[ERROR] Variable PDK not set!"
	exit $ERR_NO_VAR
fi
if [ -z "$PDKPATH" ]; then
	echo "[ERROR] Variable PDKPATH not set!"
	exit $ERR_NO_VAR
fi

# check that the PDK is supported
# -------------------------------

if echo "$PDK" | grep -q -i "sky130"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] sky130 PDK selected."
elif echo "$PDK" | grep -q -i "gf180mcu"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] gf180mcu PDK selected."
elif echo "$PDK" | grep -q -i "ihp-sg13g2"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13g2 PDK selected."
elif echo "$PDK" | grep -q -i "ihp-sg13cmos5l"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13cmos5l PDK selected."
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi

# a cellname (or layout file) is required
# ---------------------------------------

if [ -z "$1" ]; then
	echo "[ERROR] No cellname provided!"
	exit $ERR_NO_PARAM
fi

# check if the layout file exists, look into usual directories
# ------------------------------------------------------------

if [ -f "$1" ]; then
	# an exact file was given, accept it only if it has a known layout extension
	case "$1" in
		*.mag|*.mag.gz|*.gds|*.gds.gz)
			CELL_LAY="$1" ;;
		*)
			echo "[ERROR] Unsupported layout format <$1> (expected .mag, .mag.gz, .gds, .gds.gz, .klay.gds)!"
			exit $ERR_UNKNOWN_FILE ;;
	esac
else
	# otherwise derive the layout file from the cellname, resolved against the current dir.
	# The list encodes the lookup priority, the magic view is found before the GDS views.
	CELL_LAY=""
	for _lay in "$1.mag" "$1.mag.gz" "$1.gds" "$1.gds.gz" "$1.klay.gds"; do
		if [ -f "$_lay" ]; then
			CELL_LAY="$_lay"
			break
		fi
	done
	if [ -z "$CELL_LAY" ]; then
		echo "[ERROR] Layout <$1> not found!"
		exit $ERR_FILE_NOT_FOUND
	fi
fi

[ $DEBUG -eq 1 ] && echo "[INFO] Using layout file <$CELL_LAY>."

# check that the required tools are available
# -------------------------------------------

if [ "$RUN_MAGIC" -eq 1 ]; then
	if [ ! -x "$(command -v magic)" ]; then
		echo "[ERROR] Magic could not be found!"
		exit $ERR_CMD_NOT_FOUND
	fi
fi

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	for cmd in klayout python3; do
		if [ ! -x "$(command -v "$cmd")" ]; then
			echo "[ERROR] $cmd could not be found!"
			exit $ERR_CMD_NOT_FOUND
		fi
	done
fi

# KLayout DRC is implemented for sky130/gf180mcu/ihp-sg13g2/ihp-sg13cmos5l and needs a GDS layout. In each unmet case skip KLayout: warn and continue if Magic DRC also runs, otherwise error out.
# ----------------------------------------------------------------------------------------------

if [ "$RUN_KLAYOUT" -eq 1 ] && ! echo "$PDK" | grep -q -i -E "sky130|gf180mcu|ihp-sg13g2|ihp-sg13cmos5l"; then
	if [ "$RUN_MAGIC" -eq 1 ]; then
		echo "[WARNING] KLayout DRC for $PDK not yet supported, running Magic DRC only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout DRC for $PDK not yet supported!"
		exit $ERR_PDK_NOT_SUPPORTED
	fi
fi
if [ "$RUN_KLAYOUT" -eq 1 ]; then
	case "$CELL_LAY" in
		*.mag|*.mag.gz)
			if [ "$RUN_MAGIC" -eq 1 ]; then
				echo "[WARNING] KLayout DRC needs a GDS layout, running Magic DRC only."
				RUN_KLAYOUT=0
			else
				echo "[ERROR] KLayout DRC needs a GDS layout (got <$CELL_LAY>)!"
				exit $ERR_UNKNOWN_FILE
			fi
			;;
	esac
fi

# define useful variables
# -----------------------

# keep the cell name verbatim (basename only, strip a known layout extension) so names containing dots are not truncated.
# A KLayout-drawn layout uses the <cell>.klay.gds naming convention, so the .klay marker is stripped as well to reach the GDS top cell name.
CELL_NAME=$(basename "$CELL_LAY")
case "$CELL_NAME" in
	*.klay.gds)	CELL_NAME=${CELL_NAME%.klay.gds} ;;
	*.mag.gz)	CELL_NAME=${CELL_NAME%.mag.gz} ;;
	*.gds.gz)	CELL_NAME=${CELL_NAME%.gds.gz} ;;
	*.mag)		CELL_NAME=${CELL_NAME%.mag} ;;
	*.gds)		CELL_NAME=${CELL_NAME%.gds} ;;
esac
# run dir holding the Magic DRC report, log, and generated extract script. It is wiped at the start of each Magic run.
MAGIC_RUNDIR="$RESDIR/${CELL_NAME}.magic.drc"
EXT_SCRIPT="$MAGIC_RUNDIR/drc_$CELL_NAME.tcl"
# run dir holding the gf180mcu/ihp KLayout DRC report(s) (.lyrdb) and log, sky130 writes its reports directly into $RESDIR
KLAYOUT_RUNDIR="$RESDIR/${CELL_NAME}.klayout.drc"
# GDS only: magic writes this marker if the GDS top cell is not named like the loaded cell. It is checked after the run.
CELL_MISMATCH_MARKER="$MAGIC_RUNDIR/drc_$CELL_NAME.cellmismatch"
[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"

# remove old result files when requested (-c)
# -------------------------------------------

if [ "$RUN_CLEAN" -eq 1 ]; then
	rm -f  -- "$RESDIR"/*.magic.*.rpt "$RESDIR"/*.magic.*.log
	rm -f  -- "$RESDIR"/*.klayout.*.xml "$RESDIR"/*.klayout.*.log
	rm -rf -- "$RESDIR"/*.magic.drc
	rm -rf -- "$RESDIR"/*.klayout.drc
fi

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

# initial checks passed, start working
# ------------------------------------

echo "[INFO] Running DRC of <$CELL_LAY>."
echo "[INFO] Results are put into <$RESDIR>."

# ============================================================================
# Magic DRC
# ============================================================================

if [ "$RUN_MAGIC" -eq 1 ]; then
	echo "[INFO] Launching Magic DRC..."

	# the run dir is wiped so its contents only reflect this run
	rm -rf "$MAGIC_RUNDIR"
	mkdir -p "$MAGIC_RUNDIR"

	# generate the DRC script for Magic, match the file extension only, not an occurrence in the path
	case "$CELL_LAY" in
		*.mag)
			[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on the .mag file."
			{
				echo "crashbackups stop"
				echo "load $CELL_LAY"
			} > "$EXT_SCRIPT"
			;;
		*.gds)
			[ $DEBUG -eq 1 ] && echo "[INFO] Magic runs DRC on the .gds file."
			{
				echo "crashbackups stop"
				[ -n "$FLATGLOB" ] && echo "gds flatglob $FLATGLOB"
				echo "gds read $CELL_LAY"
				# Magic loads the cell named $CELL_NAME. If the GDS has no such top cell it would silently load an empty cell and report a clean DRC. So check for it first and, if missing, write the found top cells to a marker and quit.
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
		echo "set drc_rpt_path $MAGIC_RUNDIR/$CELL_NAME.magic.drc.rpt"
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
		echo 'quit -noprompt'
	} >> "$EXT_SCRIPT"

	# run the DRC in the background, the result is evaluated after the wait below
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT" \
		> "$MAGIC_RUNDIR/$CELL_NAME.magic.drc.log" 2>&1 &
fi

# ============================================================================
# KLayout DRC (per PDK deck or run_drc.py wrapper)
# ============================================================================

# run the given parts in at most <lanes> background lanes, each lane works through its parts one after another. The parts are dealt in snake order (lane 1, 2, ..., n, n, ..., 2, 1, 1, ...), so the long parts listed first land in different lanes.
run_lanes() {
	_lanes=$1
	_func=$2
	shift 2
	_l=0
	while [ "$_l" -lt "$_lanes" ]; do
		eval "_lane_$_l=''"
		_l=$((_l + 1))
	done
	_i=0
	for _part in "$@"; do
		_l=$((_i % (2 * _lanes)))
		[ "$_l" -ge "$_lanes" ] && _l=$((2 * _lanes - 1 - _l))
		eval "_lane_$_l=\"\$_lane_$_l $_part\""
		_i=$((_i + 1))
	done
	_l=0
	while [ "$_l" -lt "$_lanes" ]; do
		eval "_parts=\$_lane_$_l"
		if [ -n "$_parts" ]; then
			# shellcheck disable=SC2086
			( for _part in $_parts; do "$_func" "$_part"; done ) &
		fi
		_l=$((_l + 1))
	done
}

# run one sky130 deck in the foreground, report <cell>.klayout.drc.<deck>.xml, the log <cell>.klayout.drc.<deck>.log ends with the KLayout exit status
sky130_deck() {
	_base="$RESDIR/$CELL_NAME.klayout.drc.$1"
	case "$1" in
		# off-grid is folded into the FEOL pass (on for macro/regular, off for precheck)
		feol)		set -- -rd feol=true -rd beol=false -rd offgrid="$SKY130_OFFGRID" -r "$PDKPATH/libs.tech/klayout/drc/${PDK}_mr.drc" ;;
		beol)		set -- -rd feol=false -rd beol=true -rd offgrid=false -r "$PDKPATH/libs.tech/klayout/drc/${PDK}_mr.drc" ;;
		# chip-level fill check
		density)	set -- -r "$PDKPATH/libs.tech/klayout/drc/met_min_ca_density.lydrc" ;;
		# pin/label check, more threads bring no gain here
		pincheck)	set -- -rd threads=1 -rd flat_mode=true -r "$PDKPATH/libs.tech/klayout/drc/pin_label_purposes_overlapping_drawing.rb.drc" ;;
		# zero-area geometry
		zeroarea)	set -- -r "$PDKPATH/libs.tech/klayout/drc/zeroarea.rb.drc" ;;
	esac
	klayout -b -rd input="$CELL_LAY" -rd report="$_base.xml" "$@" > "$_base.log" 2>&1
	echo "[INFO] KLayout exit status: $?" >> "$_base.log"
}

# run one ihp part in the foreground, its log is <dir>/<cell>.drc.log. main and all write into $KLAYOUT_RUNDIR, the other parts into a subfolder named after them.
# main, density, antenna, and all go through run_drc.py. maximal runs the extra-rules deck directly with the switches run_drc.py would pass, because run_drc.py can only run it after main, and its log ends with the KLayout exit status.
# shellcheck disable=SC2086
ihp_part() {
	_dir="$KLAYOUT_RUNDIR"
	case "$1" in
		main|all)	;;
		*)		_dir="$KLAYOUT_RUNDIR/$1"; mkdir -p "$_dir" ;;
	esac
	case "$1" in
		maximal)
			klayout -b \
				-rd input="$CELL_LAY" \
				-rd topcell="$CELL_NAME" \
				-rd report="$_dir/$CELL_NAME.maximal.lyrdb" \
				-rd log="$_dir/$CELL_NAME.maximal.log" \
				-rd threads=1 \
				-rd run_mode=deep \
				-rd no_recommended=false \
				-rd no_offgrid=false \
				-r "$IHP_MAXIMAL" \
				> "$_dir/$CELL_NAME.drc.log" 2>&1
			echo "[INFO] KLayout exit status: $?" >> "$_dir/$CELL_NAME.drc.log"
			return ;;
		main)		set -- --disable_extra_rules --no_density --mp=1 --density_thr=1 ;;
		density)	set -- --density_only --mp=1 --density_thr=1 ;;
		antenna)	set -- --antenna_only --mp=1 --density_thr=1 ;;
		all)		set -- $DRC_FLAGS --mp="$IHP_MP" --density_thr="$IHP_THR" ;;
	esac
	python3 "$PDKPATH/libs.tech/klayout/tech/drc/run_drc.py" \
		--path="$CELL_LAY" \
		--topcell="$CELL_NAME" \
		--run_dir="$_dir" \
		"$@" \
		> "$_dir/$CELL_NAME.drc.log" 2>&1
}

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	echo "[INFO] Launching KLayout DRC..."

	# remove old result files so they only reflect this run
	rm -f "$RESDIR/$CELL_NAME".klayout.*.xml

	if echo "$PDK" | grep -q -i "sky130"; then
		# map the DRC level onto the sky130 decks, the FEOL and BEOL core rules always run
		# precheck: core rules only
		# macro: adds off-grid, pin, and zero-area, skips chip-level density
		# regular: all checks
		# SKY130_DENSITY/PIN/ZEROAREA and SKY130_DECKS are read again in the evaluate-results section below
		SKY130_OFFGRID=true
		SKY130_DENSITY=1
		SKY130_PIN=1
		SKY130_ZEROAREA=1
		case "$DRC_LEVEL" in
			precheck)	SKY130_OFFGRID=false; SKY130_DENSITY=0; SKY130_PIN=0; SKY130_ZEROAREA=0 ;;
			macro)		SKY130_DENSITY=0 ;;
		esac

		# every deck is its own KLayout process, listed longest first (on sky130_sram_1kbyte: BEOL 34 s, FEOL 25 s, pin check 11 s, density 5 s, zero-area 2.5 s)
		SKY130_DECKS="beol feol"
		[ "$SKY130_PIN" -eq 1 ] && SKY130_DECKS="$SKY130_DECKS pincheck"
		[ "$SKY130_DENSITY" -eq 1 ] && SKY130_DECKS="$SKY130_DECKS density"
		[ "$SKY130_ZEROAREA" -eq 1 ] && SKY130_DECKS="$SKY130_DECKS zeroarea"
		# without -j all decks start at once as before, on a small cell most of each deck is the 2.5 s KLayout start
		SKY130_LANES=0
		for _deck in $SKY130_DECKS; do
			SKY130_LANES=$((SKY130_LANES + 1))
		done
		[ "$JOBS_SET" -eq 1 ] && [ "$JOBS" -lt "$SKY130_LANES" ] && SKY130_LANES=$JOBS
		# shellcheck disable=SC2086
		run_lanes "$SKY130_LANES" sky130_deck $SKY130_DECKS
	elif echo "$PDK" | grep -q -i "gf180mcu"; then
		# gf180mcu runs the gf180mcu.drc framework deck directly. The scope is selected with -rd decks=<comma-separated tags>, a leading '-' excludes a tag.
		# precheck: core rules only, drops off-grid, density, and antenna
		# macro: skips chip-level density and antenna
		# regular: all checks
		case "$DRC_LEVEL" in
			precheck)	DRC_DECKS="all,-offgrid,-density,-antenna" ;;
			macro)		DRC_DECKS="all,-density,-antenna" ;;
			regular)	DRC_DECKS="all" ;;
		esac
		rm -rf "$KLAYOUT_RUNDIR"
		mkdir -p "$KLAYOUT_RUNDIR"
		KLAYOUT_PARTS="gf180"
		# a single process with -j threads. variant=$PDK selects the matching gf180mcu stack preset (metal_top/metal_level/mim_option). The log ends with the KLayout exit status.
		{
			klayout -b \
				-rd input="$CELL_LAY" \
				-rd report="$KLAYOUT_RUNDIR/$CELL_NAME.lyrdb" \
				-rd topcell="$CELL_NAME" \
				-rd variant="$PDK" \
				-rd run_mode=deep \
				-rd threads="$JOBS" \
				-rd decks="$DRC_DECKS" \
				-r "$PDKPATH/libs.tech/klayout/tech/drc/gf180mcu.drc" \
				> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log" 2>&1
			echo "[INFO] KLayout exit status: $?" >> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log"
		} &
	elif echo "$PDK" | grep -q -i -E "ihp-sg13g2|ihp-sg13cmos5l"; then
		# the ihp-sg13g2 and ihp-sg13cmos5l wrappers share the same CLI, both write their .lyrdb report(s) into --run_dir
		# precheck: minimal foundry precheck rule set, drops density, off-grid, angle, extra, and recommended rules
		# macro: skips chip-level density and the extra rules
		# regular: all checks plus antenna
		case "$DRC_LEVEL" in
			precheck)	DRC_FLAGS="--precheck_drc --no_density --no_offgrid --no_angle --disable_extra_rules --no_recommended" ;;
			macro)		DRC_FLAGS="--no_density --disable_extra_rules" ;;
			regular)	DRC_FLAGS="--antenna" ;;
		esac
		rm -rf "$KLAYOUT_RUNDIR"
		mkdir -p "$KLAYOUT_RUNDIR"
		# the extra-rules deck of this PDK (sg13g2_maximal.drc, sg13cmos5l_maximal.drc)
		IHP_MAXIMAL="$PDKPATH/libs.tech/klayout/tech/drc/rule_decks/${PDK#ihp-}_maximal.drc"
		# --mp > 1 starts one KLayout process per rule table (37 in ihp-sg13g2), each reading the layout and deriving its layers again. That only pays off for large layouts, so it is used above -j 4 only. --density_thr reaches every process as its thread count.
		if [ "$JOBS" -gt 4 ]; then
			IHP_MP=$JOBS
			IHP_THR=1
		else
			IHP_MP=1
			IHP_THR=$JOBS
		fi
		if [ "$DRC_LEVEL" = "regular" ] && [ "$JOBS" -le 4 ] && [ -f "$IHP_MAXIMAL" ]; then
			# regular runs four decks, which run_drc.py --mp=1 runs one after another. As separate parts they run in up to 4 lanes, main and the extra rules (the long ones) in different lanes.
			KLAYOUT_PARTS="main maximal density antenna"
			# shellcheck disable=SC2086
			run_lanes "$JOBS" ihp_part $KLAYOUT_PARTS
		else
			KLAYOUT_PARTS="all"
			ihp_part all &
		fi
	fi
fi

# wait for all runs to finish
# ---------------------------

wait
echo "---"

# the decompressed layout is no longer needed after the DRC runs
[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"

# ============================================================================
# evaluate results
# ============================================================================

DRC_CLEAN=1

if [ "$RUN_MAGIC" -eq 1 ]; then
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

	# GDS top cell did not match the loaded cell name (marker written by magic above), report the specific cause instead of the generic error below
	if [ -f "$CELL_MISMATCH_MARKER" ]; then
		echo "[ERROR] GDS top cell does not match <$CELL_NAME>!"
		echo "[ERROR] GDS top cell(s) found: <$(cat "$CELL_MISMATCH_MARKER")>."
		echo "[ERROR] Rename the layout file/cell so they match, then re-run."
		rm -f "$CELL_MISMATCH_MARKER"
		exit $ERR_NO_OUTPUT
	fi

	if [ ! -f "$MAGIC_RUNDIR/$CELL_NAME.magic.drc.rpt" ]; then
		echo "[ERROR] Magic DRC produced no report, see <$MAGIC_RUNDIR/$CELL_NAME.magic.drc.log>!"
		exit $ERR_NO_OUTPUT
	fi

	if grep -q "COUNT: 0" "$MAGIC_RUNDIR/$CELL_NAME.magic.drc.rpt"; then
		echo "[INFO] Magic DRC is clean!"
	else
		echo "[INFO] Magic DRC errors found! Check <$MAGIC_RUNDIR/$CELL_NAME.magic.drc.rpt>!"
		DRC_CLEAN=0
	fi
fi

if [ "$RUN_KLAYOUT" -eq 1 ] && echo "$PDK" | grep -q -i "sky130"; then
	# SKY130_DENSITY/PIN/ZEROAREA were set in the KLayout launch section above and gate which per-check reports exist at this level
	# a deck that crashed may still have left a report. KLayout logs an uncaught error as "ERROR: ...", and sky130_deck ends every log with the KLayout exit status.
	# The pin check exits 2 to 127 when it finds something (1 is its internal error, 128 and up a signal). The zero-area deck exits with its finding count modulo 256, so its status cannot tell a crash. The other decks exit 0.
	for _deck in $SKY130_DECKS; do
		_log="$RESDIR/$CELL_NAME.klayout.drc.$_deck.log"
		_rc=$(tail -n 1 "$_log" 2>/dev/null | sed -n 's/^\[INFO\] KLayout exit status: \([0-9][0-9]*\)$/\1/p')
		_failed=0
		[ -z "$_rc" ] && _failed=1
		grep -q "^ERROR: " "$_log" 2>/dev/null && _failed=1
		case "$_deck" in
			pincheck)	{ [ "${_rc:-1}" -eq 1 ] || [ "${_rc:-1}" -ge 128 ]; } && _failed=1 ;;
			zeroarea)	;;
			*)		[ "$_rc" = "0" ] || _failed=1 ;;
		esac
		if [ "$_failed" -eq 1 ]; then
			echo "[ERROR] KLayout $_deck DRC failed, see <$_log>!"
			exit $ERR_NO_OUTPUT
		fi
	done
	# each KLayout report violation is one <item> regardless of its geometry type (edge pair, polygon, edge, ...), so count the <item> occurrences
	if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.feol.xml" ]; then
		echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
		exit $ERR_NO_OUTPUT
	fi
	DRC_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.feol.xml")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS FEOL DRC errors found! Check <$RESDIR/$CELL_NAME.klayout.drc.feol.xml>!"
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
		echo "[INFO] KLayout $DRC_ERRORS BEOL DRC errors found! Check <$RESDIR/$CELL_NAME.klayout.drc.beol.xml>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout BEOL DRC is clean!"
	fi

	if [ "$SKY130_DENSITY" -eq 1 ]; then
		if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.density.xml" ]; then
			echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
			exit $ERR_NO_OUTPUT
		fi
		DENSITY_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.density.xml")
		if [ "$DENSITY_ERRORS" -ne 0 ]; then
			echo "[INFO] KLayout $DENSITY_ERRORS density errors found! Check <$RESDIR/$CELL_NAME.klayout.drc.density.xml>!"
			DRC_CLEAN=0
		else
			echo "[INFO] KLayout metal density DRC is clean!"
		fi
	fi

	if [ "$SKY130_PIN" -eq 1 ]; then
		if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" ]; then
			echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
			exit $ERR_NO_OUTPUT
		fi
		PINCHECK_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml")
		if [ "$PINCHECK_ERRORS" -ne 0 ]; then
			echo "[INFO] KLayout $PINCHECK_ERRORS pin errors found! Check <$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml>!"
			DRC_CLEAN=0
		else
			echo "[INFO] KLayout pin check DRC is clean!"
		fi
	fi

	if [ "$SKY130_ZEROAREA" -eq 1 ]; then
		if [ ! -f "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" ]; then
			echo "[ERROR] KLayout DRC produced no report, see the matching .log in <$RESDIR>!"
			exit $ERR_NO_OUTPUT
		fi
		ZEROAREA_ERRORS=$(grep -c "<item>" "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml")
		if [ "$ZEROAREA_ERRORS" -ne 0 ]; then
			echo "[INFO] KLayout $ZEROAREA_ERRORS zero-area errors found! Check <$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml>!"
			DRC_CLEAN=0
		else
			echo "[INFO] KLayout zero-area DRC is clean!"
		fi
	fi
elif [ "$RUN_KLAYOUT" -eq 1 ]; then
	# gf180mcu/ihp write their .lyrdb report(s) into the run dir of each part (main, all, and gf180 use $KLAYOUT_RUNDIR, the other parts a subfolder of it). No report means the part failed (a DRC run with violations still writes one).
	# run_drc.py exits 1 for violations and for a crash alike. A crashed deck leaves a Python traceback in its log, a crashed table job of --mp > 1 leaves "generated an exception" (run_drc.py then merges the remaining reports and reports success). A deck run directly with klayout -b ends its log with the KLayout exit status.
	for _part in $KLAYOUT_PARTS; do
		case "$_part" in
			main|all|gf180)	_dir="$KLAYOUT_RUNDIR" ;;
			*)		_dir="$KLAYOUT_RUNDIR/$_part" ;;
		esac
		_log="$_dir/$CELL_NAME.drc.log"
		_failed=0
		find "$_dir" -maxdepth 1 -name '*.lyrdb' 2>/dev/null | grep -q . || _failed=1
		case "$_part" in
			gf180|maximal)	tail -n 1 "$_log" 2>/dev/null | grep -q "exit status: 0$" || _failed=1 ;;
			*)		grep -q -E "Traceback|generated an exception" "$_log" 2>/dev/null && _failed=1 ;;
		esac
		if [ "$_failed" -eq 1 ]; then
			echo "[ERROR] KLayout DRC run failed (part <$_part>), see <$_log>!"
			exit $ERR_NO_OUTPUT
		fi
	done
	# one violation is one <item> in the report, regardless of its geometry type
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
	cat <<'EOF'
      .-"""""-.
    .'  _   _  '.
   /   (o) (o)   \
  |       <       |
  |    \_____/    |
   \             /
    '.         .'
      '-.....-'
EOF
	echo "---"
else
	echo "DRC ERRORS FOUND! Please check the output files!"
	cat <<'EOF'
      .-"""""-.
    .'  _   _  '.
   /   (o) (o)   \
  |       <       |
  |     _____     |
   \             /
    '.         .'
      '-.....-'
EOF
	echo "---"
	exit $ERR_DRC
fi
echo "[DONE] Bye!"
