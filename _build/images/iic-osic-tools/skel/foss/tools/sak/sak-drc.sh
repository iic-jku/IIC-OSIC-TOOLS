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
# Usage: sak-drc.sh [-d] [-m|-k|-b|-g] [-c] [-l <level>] [-s <suite>] [-f <pattern>] [-w <workdir>] <cellname>
#        -m  Run Magic DRC (default)
#        -k  Run KLayout DRC
#        -b  Run Magic and KLayout DRC
#        -g  Run gdscheck DRC
#        -c  Clean output files before running
#        -l  KLayout/gdscheck DRC level: precheck|macro|regular (default: macro)
#        -s  gdscheck suite: precheck|core|main|density|antenna (default: derived from -l)
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
	echo "DRC script for Magic, KLayout, and gdscheck (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-m|-k|-b|-g] [-c] [-l <level>] [-s <suite>] [-f <pattern>] [-w <workdir>] <cellname>"
	echo
	echo "       -m Run Magic DRC (default)"
	echo "       -k Run KLayout DRC"
	echo "       -b Run Magic and KLayout DRC"
	echo "       -g Run gdscheck DRC"
	echo "       -c Clean output files before running"
	echo "       -l KLayout/gdscheck DRC level: precheck|macro|regular (default: macro)"
	echo "          precheck: core FEOL and BEOL rules only"
	echo "          macro: adds off-grid, pin, and zero-area checks, skips chip-level density and antenna"
	echo "          regular: all checks"
	echo "       -s gdscheck suite, overrides the -l mapping (precheck|core|main|density|antenna)"
	echo "          precheck maps to precheck, macro to core, regular to main"
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
RUN_GDSCHECK=0
RUN_CLEAN=0
FLATGLOB=""
DRC_LEVEL="macro"
GDSCHECK_SUITE=""

# check flags
# -----------

while getopts "mkbgcl:s:f:w:d" flag; do
	case $flag in
		m)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -m is set."
			RUN_MAGIC=1
			RUN_KLAYOUT=0
			RUN_GDSCHECK=0
			;;
		k)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -k is set."
			RUN_MAGIC=0
			RUN_KLAYOUT=1
			RUN_GDSCHECK=0
			;;
		b)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -b is set."
			RUN_MAGIC=1
			RUN_KLAYOUT=1
			RUN_GDSCHECK=0
			;;
		g)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -g is set."
			RUN_MAGIC=0
			RUN_KLAYOUT=0
			RUN_GDSCHECK=1
			;;
		c)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -c is set."
			RUN_CLEAN=1
			;;
		l)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -l is set to <$OPTARG>."
			DRC_LEVEL="$OPTARG"
			;;
		s)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -s is set to <$OPTARG>."
			GDSCHECK_SUITE="$OPTARG"
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

# check that the KLayout/gdscheck DRC level is valid
# --------------------------------------------------

case "$DRC_LEVEL" in
	precheck|macro|regular) ;;
	*)
		echo "[ERROR] Unknown KLayout/gdscheck DRC level <$DRC_LEVEL> (expected precheck, macro, or regular)!"
		exit $ERR_NO_PARAM ;;
esac

# check that the gdscheck suite is valid (empty means derive it from the DRC level)
# ---------------------------------------------------------------------------------

case "$GDSCHECK_SUITE" in
	""|precheck|core|main|density|antenna) ;;
	*)
		echo "[ERROR] Unknown gdscheck suite <$GDSCHECK_SUITE> (expected precheck, core, main, density, or antenna)!"
		exit $ERR_NO_PARAM ;;
esac

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

if [ "$RUN_GDSCHECK" -eq 1 ]; then
	if [ ! -x "$(command -v gdscheck)" ]; then
		echo "[ERROR] gdscheck could not be found!"
		exit $ERR_CMD_NOT_FOUND
	fi
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

# gdscheck DRC (-g) carries its own built-in rule decks for ihp-sg13g2/ihp-sg13cmos5l and needs a GDS layout. -g runs gdscheck alone, so both unmet cases error out.
# ----------------------------------------------------------------------------------------------

if [ "$RUN_GDSCHECK" -eq 1 ] && ! echo "$PDK" | grep -q -i -E "ihp-sg13g2|ihp-sg13cmos5l"; then
	echo "[ERROR] gdscheck DRC for $PDK not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi
if [ "$RUN_GDSCHECK" -eq 1 ]; then
	case "$CELL_LAY" in
		*.mag|*.mag.gz)
			echo "[ERROR] gdscheck DRC needs a GDS layout (got <$CELL_LAY>)!"
			exit $ERR_UNKNOWN_FILE
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
# run dir holding the gdscheck DRC report (.lyrdb) and log
GDSCHECK_RUNDIR="$RESDIR/${CELL_NAME}.gdscheck.drc"
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
	rm -rf -- "$RESDIR"/*.gdscheck.drc
fi

# decompress gzipped layout views, magic cannot read them directly (gdscheck detects gzip itself, so a gdscheck-only run skips this)
# ----------------------------------------------------------------

GZ_TMP=""
if [ "$RUN_MAGIC" -eq 1 ] || [ "$RUN_KLAYOUT" -eq 1 ]; then
	case "$CELL_LAY" in
		*.gds.gz)
			GZ_TMP="$RESDIR/${CELL_NAME}.drctmp.gds"
			;;
		*.mag.gz)
			GZ_TMP="$RESDIR/${CELL_NAME}.drctmp.mag"
			;;
	esac
fi
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

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	echo "[INFO] Launching KLayout DRC..."

	# remove old result files so they only reflect this run
	rm -f "$RESDIR/$CELL_NAME".klayout.*.xml

	if echo "$PDK" | grep -q -i "sky130"; then
		# map the DRC level onto the sky130 decks, the FEOL and BEOL core rules always run
		# precheck: core rules only
		# macro: adds off-grid, pin, and zero-area, skips chip-level density
		# regular: all checks
		# SKY130_DENSITY/PIN/ZEROAREA are read again in the evaluate-results section below
		SKY130_OFFGRID=true
		SKY130_DENSITY=1
		SKY130_PIN=1
		SKY130_ZEROAREA=1
		case "$DRC_LEVEL" in
			precheck)	SKY130_OFFGRID=false; SKY130_DENSITY=0; SKY130_PIN=0; SKY130_ZEROAREA=0 ;;
			macro)		SKY130_DENSITY=0 ;;
		esac

		# off-grid is folded into the FEOL pass (on for macro/regular, off for precheck)
		klayout -b \
			-rd input="$CELL_LAY" \
			-rd feol=true \
			-rd beol=false \
			-rd offgrid="$SKY130_OFFGRID" \
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

		# density: chip-level fill check, regular only
		if [ "$SKY130_DENSITY" -eq 1 ]; then
			klayout -b \
				-rd input="$CELL_LAY" \
				-rd report="$RESDIR/$CELL_NAME.klayout.drc.density.xml" \
				-r "$PDKPATH/libs.tech/klayout/drc/met_min_ca_density.lydrc" \
				> "$RESDIR/$CELL_NAME.klayout.drc.density.log" 2>&1 &
		fi

		# pin/label check: macro and regular
		if [ "$SKY130_PIN" -eq 1 ]; then
			klayout -b \
				-rd input="$CELL_LAY" \
				-rd threads="$(nproc --ignore 5)" \
				-rd flat_mode=true \
				-rd report="$RESDIR/$CELL_NAME.klayout.drc.pincheck.xml" \
				-r "$PDKPATH/libs.tech/klayout/drc/pin_label_purposes_overlapping_drawing.rb.drc" \
				> "$RESDIR/$CELL_NAME.klayout.drc.pincheck.log" 2>&1 &
		fi

		# zero-area geometry: macro and regular
		if [ "$SKY130_ZEROAREA" -eq 1 ]; then
			klayout -b \
				-rd input="$CELL_LAY" \
				-rd report="$RESDIR/$CELL_NAME.klayout.drc.zeroarea.xml" \
				-r "$PDKPATH/libs.tech/klayout/drc/zeroarea.rb.drc" \
				> "$RESDIR/$CELL_NAME.klayout.drc.zeroarea.log" 2>&1 &
		fi
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
		# variant=$PDK selects the matching gf180mcu stack preset (metal_top/metal_level/mim_option)
		klayout -b \
			-rd input="$CELL_LAY" \
			-rd report="$KLAYOUT_RUNDIR/$CELL_NAME.lyrdb" \
			-rd topcell="$CELL_NAME" \
			-rd variant="$PDK" \
			-rd run_mode=deep \
			-rd threads="$(nproc --ignore 5)" \
			-rd decks="$DRC_DECKS" \
			-r "$PDKPATH/libs.tech/klayout/tech/drc/gf180mcu.drc" \
			> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log" 2>&1 &
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
		# --mp splits the rule deck for parallel execution, --density_thr sets the thread count of the density run
		# shellcheck disable=SC2086
		python3 "$PDKPATH/libs.tech/klayout/tech/drc/run_drc.py" \
			--path="$CELL_LAY" \
			--topcell="$CELL_NAME" \
			--run_dir="$KLAYOUT_RUNDIR" \
			$DRC_FLAGS \
			--mp="$(nproc --ignore 5)" \
			--density_thr="$(nproc --ignore 5)" \
			> "$KLAYOUT_RUNDIR/$CELL_NAME.drc.log" 2>&1 &
	fi
fi

# ============================================================================
# gdscheck DRC (standalone engine with built-in ihp rule decks)
# ============================================================================

if [ "$RUN_GDSCHECK" -eq 1 ]; then
	echo "[INFO] Launching gdscheck DRC..."

	# map the DRC level onto the gdscheck suites unless -s selected one directly
	# precheck: IHP's published open-source precheck subset
	# macro: core suite, all geometric rules minus density/fill and antenna
	# regular: main suite, every per-layer deck including density and antenna
	if [ -z "$GDSCHECK_SUITE" ]; then
		case "$DRC_LEVEL" in
			precheck)	GDSCHECK_SUITE="precheck" ;;
			macro)		GDSCHECK_SUITE="core" ;;
			regular)	GDSCHECK_SUITE="main" ;;
		esac
	fi
	[ $DEBUG -eq 1 ] && echo "[INFO] Using gdscheck suite <$GDSCHECK_SUITE>."

	# the run dir is wiped so its contents only reflect this run
	rm -rf "$GDSCHECK_RUNDIR"
	mkdir -p "$GDSCHECK_RUNDIR"

	# net extraction is lazy and only triggered by the antenna rules (main/antenna suites), so no --no-connectivity switch is needed
	gdscheck run \
		--input "$CELL_LAY" \
		--process "$PDK" \
		--suite "$GDSCHECK_SUITE" \
		--topcell "$CELL_NAME" \
		--report "$GDSCHECK_RUNDIR/$CELL_NAME.lyrdb" \
		--threads "$(nproc --ignore 5)" \
		> "$GDSCHECK_RUNDIR/$CELL_NAME.drc.log" 2>&1 &
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
	# gf180mcu/ihp write their .lyrdb report(s) into the run dir. No report means the run itself failed (a DRC run with violations still writes one), the reason is in the log.
	if ! find "$KLAYOUT_RUNDIR" -name '*.lyrdb' 2>/dev/null | grep -q .; then
		echo "[ERROR] KLayout DRC run failed (no report produced), see <$KLAYOUT_RUNDIR/$CELL_NAME.drc.log>!"
		exit $ERR_NO_OUTPUT
	fi
	# one violation is one <item> in the report, regardless of its geometry type
	DRC_ERRORS=$(find "$KLAYOUT_RUNDIR" -name '*.lyrdb' -exec cat {} + 2>/dev/null | grep -c "<item>")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] KLayout $DRC_ERRORS DRC errors found! Check <$KLAYOUT_RUNDIR>!"
		DRC_CLEAN=0
	else
		echo "[INFO] KLayout DRC is clean!"
	fi
fi

if [ "$RUN_GDSCHECK" -eq 1 ]; then
	# gdscheck writes its .lyrdb report for clean and dirty runs alike and always exits 0, so no report means the run itself failed (e.g. topcell not found), the reason is in the log
	if [ ! -f "$GDSCHECK_RUNDIR/$CELL_NAME.lyrdb" ]; then
		echo "[ERROR] gdscheck DRC run failed (no report produced), see <$GDSCHECK_RUNDIR/$CELL_NAME.drc.log>!"
		exit $ERR_NO_OUTPUT
	fi
	# one violation is one <item> in the report, regardless of its geometry type
	DRC_ERRORS=$(grep -c "<item>" "$GDSCHECK_RUNDIR/$CELL_NAME.lyrdb")
	if [ "$DRC_ERRORS" -ne 0 ]; then
		echo "[INFO] gdscheck $DRC_ERRORS DRC errors found! Check <$GDSCHECK_RUNDIR/$CELL_NAME.lyrdb>!"
		DRC_CLEAN=0
	else
		echo "[INFO] gdscheck DRC is clean!"
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
