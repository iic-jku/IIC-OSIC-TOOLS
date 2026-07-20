#!/bin/sh
# ========================================================================
# PEX (Parasitic Extraction) Script for Open-Source IC Design
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
# Usage: sak-pex.sh [-d] [-m <mode>] [-s <mode>] [-n <subcktname>] [-w <workdir>]
#                   [-t <threshold>] [-r <minres>] [-y <mindelay>] <cellname>
#        -m  Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)
#        -s  Subcircuit definition (1 = include [default], 0 = no subcircuit)
#        -n  Name of PEX subcircuit (default: <cellname>)
#        -w  Use <workdir> to store result files (default: current dir)
#        -t  full-RC only: extresist threshold in mOhm (default: 10000 = 10 Ohm)
#        -r  full-RC only: extresist minres in mOhm (default: 1000 = 1 Ohm)
#        -y  full-RC only: extresist mindelay in ps (default: 1, 0 = gate by resistance)
#        -d  Enable debug information
#
#        <cellname> may be a cell name or a layout file (.mag, .mag.gz, .gds, .gds.gz)
#        NOTE: for a GDS input the top cell must be named like the file, otherwise the script aborts
#
# Example: sak-pex.sh -m 3 -t 5000 -r 500 -y 2 -n mycell_pex -w ./results mycell.gds
# ========================================================================

ERR_GENERAL=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_WRONG_MODE=4
ERR_CMD_NOT_FOUND=5
ERR_PDK_NOT_SUPPORTED=6
ERR_UNKNOWN_FILE=7
ERR_NO_VAR=8

if [ $# -eq 0 ]; then
	echo
	echo "PEX script using Magic (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-m <mode>] [-s <mode>] [-n <subcktname>] [-w <workdir>]"
	echo "       [-t <threshold>] [-r <minres>] [-y <mindelay>] <cellname>"
	echo
	echo "       -m Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)"
	echo "       -s Subcircuit definition in PEX netlist (1 = include subcircuit definition [default], 0 = no subcircuit)"
	echo "       -n Name of PEX subcircuit (default is <cellname>)"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -t full-RC only: extresist threshold in mOhm (default 10000 = 10 Ohm)"
	echo "       -r full-RC only: extresist minres in mOhm (default 1000 = 1 Ohm)"
	echo "       -y full-RC only: extresist mindelay in ps (default 1, 0 = gate by resistance instead of delay)"
	echo "       -d Enable debug information"
	echo
	echo "       <cellname> may be a cell name or a layout file (.mag, .mag.gz, .gds, .gds.gz)"
	echo "       NOTE: for a GDS input the top cell must be named like the file (<cellname>)"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

DEBUG=0
RESDIR=$PWD
GDS_MODE=0
EXT_MODE=2
SUBCIRCUIT=1
CELL_NAME_SET=0

# full-RC (extresist) defaults, matching Magic's own defaults
EXT_THRESHOLD=10000	# mOhm: coarse end-to-end resistance gating extraction
EXT_MINRES=1000		# mOhm: resistors below this are merged (simplification)
EXT_MINDELAY=1		# ps: delay-based output gating (0 = gate by resistance)

# check flags
# -----------

while getopts "m:s:n:w:t:r:y:d" flag; do
	case $flag in
		m)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -m is set to <$OPTARG>."
			EXT_MODE=${OPTARG}
			;;
		s)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -s is set to <$OPTARG>."
			SUBCIRCUIT=${OPTARG}
			;;
		n)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -n is set to <$OPTARG>."
			CELL_NAME_SET=1
			CELL_NAME_PEX=${OPTARG}
			;;
		w)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -w is set to <$OPTARG>."
			# -m so a not-yet-existing (multi-level) workdir still resolves. It is created below.
			RESDIR=$(realpath -m "$OPTARG")
			;;
		t)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -t is set to <$OPTARG>."
			EXT_THRESHOLD=${OPTARG}
			;;
		r)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -r is set to <$OPTARG>."
			EXT_MINRES=${OPTARG}
			;;
		y)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -y is set to <$OPTARG>."
			EXT_MINDELAY=${OPTARG}
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

# check that the PEX mode and subcircuit setting are valid
# --------------------------------------------------------

if [ -n "$EXT_MODE" ] && [ "$EXT_MODE" -eq "$EXT_MODE" ] 2>/dev/null; then
	if [ "$EXT_MODE" -lt 1 ] || [ "$EXT_MODE" -gt 3 ]; then
		echo "[ERROR] Unknown extraction mode!"
		exit $ERR_WRONG_MODE
	fi
else
	echo "[ERROR] Extraction mode must be an integer!"
	exit $ERR_WRONG_MODE
fi

if [ -n "$SUBCIRCUIT" ] && [ "$SUBCIRCUIT" -eq "$SUBCIRCUIT" ] 2>/dev/null; then
	if [ "$SUBCIRCUIT" -lt 0 ] || [ "$SUBCIRCUIT" -gt 1 ]; then
		echo "[ERROR] Illegal subcircuit mode!"
		exit $ERR_WRONG_MODE
	fi
else
	echo "[ERROR] Subcircuit mode must be an integer!"
	exit $ERR_WRONG_MODE
fi

# check that the full-RC extresist parameters are non-negative integers
# ---------------------------------------------------------------------

for _ext_par in "threshold:$EXT_THRESHOLD" "minres:$EXT_MINRES" "mindelay:$EXT_MINDELAY"; do
	_ext_name=${_ext_par%%:*}
	_ext_val=${_ext_par#*:}
	if [ -n "$_ext_val" ] && [ "$_ext_val" -eq "$_ext_val" ] 2>/dev/null; then
		if [ "$_ext_val" -lt 0 ]; then
			echo "[ERROR] extresist $_ext_name must be >= 0!"
			exit $ERR_WRONG_MODE
		fi
	else
		echo "[ERROR] extresist $_ext_name must be an integer!"
		exit $ERR_WRONG_MODE
	fi
done

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
elif [ -f "lay/$1.mag" ]; then
	CELL_LAY="lay/$1.mag"
elif [ -f "lay/$1.mag.gz" ]; then
	CELL_LAY="lay/$1.mag.gz"
elif [ -f "lay/$1.gds" ]; then
	CELL_LAY="lay/$1.gds"
elif [ -f "lay/$1.gds.gz" ]; then
	CELL_LAY="lay/$1.gds.gz"
elif [ -f "mag/$1.mag" ]; then
	CELL_LAY="mag/$1.mag"
elif [ -f "mag/$1.mag.gz" ]; then
	CELL_LAY="mag/$1.mag.gz"
elif [ -f "gds/$1.gds" ]; then
	CELL_LAY="gds/$1.gds"
elif [ -f "gds/$1.gds.gz" ]; then
	CELL_LAY="gds/$1.gds.gz"
else
	echo "[ERROR] Layout <$1> not found!"
	exit $ERR_FILE_NOT_FOUND
fi

[ $DEBUG -eq 1 ] && echo "[INFO] Using layout file <$CELL_LAY>."

# check that the required tools are available
# -------------------------------------------

if [ ! -x "$(command -v magic)" ]; then
	echo "[ERROR] Magic could not be found!"
	exit $ERR_CMD_NOT_FOUND
fi

# define useful variables
# -----------------------

# keep the cell name verbatim (basename only, strip a known layout extension) so names containing dots are not truncated
CELL_NAME=$(basename "$CELL_LAY")
case "$CELL_NAME" in
	*.mag.gz)	CELL_NAME=${CELL_NAME%.mag.gz} ;;
	*.gds.gz)	CELL_NAME=${CELL_NAME%.gds.gz} ;;
	*.mag)		CELL_NAME=${CELL_NAME%.mag} ;;
	*.gds)		CELL_NAME=${CELL_NAME%.gds} ;;
esac
EXT_SCRIPT="$RESDIR/pex_$CELL_NAME.tcl"
NETLIST_PEX="$RESDIR/$CELL_NAME.pex.spice"
PEX_LOG="$RESDIR/$CELL_NAME.pex.log"
# GDS only: Magic writes this marker if the GDS top cell is not named like the file. It is checked after the run.
CELL_MISMATCH_MARKER="$RESDIR/pex_$CELL_NAME.cellmismatch"
# the PEX subcircuit is named like the cell unless -n was given
[ "$CELL_NAME_SET" -eq 0 ] && CELL_NAME_PEX=${CELL_NAME}
[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"

# remove old result files
# -----------------------

# a stale netlist fragment or marker from an aborted run must not be mistaken for output of this run
rm -f "$NETLIST_PEX.tmp"
rm -f "$CELL_MISMATCH_MARKER"

# decompress gzipped layout views, Magic cannot read them directly
# ----------------------------------------------------------------

# a .mag.gz must keep its cell name (<cell>.mag) so Magic loads it as $CELL_NAME. A private temp dir keeps that name without clobbering anything.
TMP_MAG_DIR=""
# a .gds.gz is decompressed into the result dir under a cell-specific name so runs do not collide. Both temp copies are removed during cleanup.
TMP_GDS=""
case "$CELL_LAY" in
	*.mag.gz)
		TMP_MAG_DIR="$RESDIR/.pextmp_${CELL_NAME}_$$"
		mkdir -p "$TMP_MAG_DIR"
		gunzip -c "$CELL_LAY" > "$TMP_MAG_DIR/${CELL_NAME}.mag"
		CELL_LAY="$TMP_MAG_DIR/${CELL_NAME}.mag"
		;;
	*.gds.gz)
		TMP_GDS="$RESDIR/${CELL_NAME}.pextmp.gds"
		gunzip -c "$CELL_LAY" > "$TMP_GDS"
		CELL_LAY="$TMP_GDS"
		;;
esac
case "$CELL_LAY" in
	*.gds)
		GDS_MODE=1
		[ $DEBUG -eq 1 ] && echo "[INFO] GDS mode is selected."
		;;
esac

# initial checks passed, start working
# ------------------------------------

echo "[INFO] Running PEX of <$CELL_LAY>."
echo "[INFO] Results are put into <$RESDIR>."

# generate the extract script for Magic
# -------------------------------------

case "$EXT_MODE" in
	1)	EXT_MODE_TEXT="C-decoupled" ;;
	2)	EXT_MODE_TEXT="C-coupled" ;;
	3)	EXT_MODE_TEXT="full-RC" ;;
esac

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
	# we read a .gds/.gds.gz view. Magic loads the cell named $CELL_NAME. If the GDS has no such top cell it would silently load an empty cell and produce an empty netlist. So check for it first and, if missing, write the found top cells to a marker and quit.
	{
		echo "gds read ${CELL_LAY}"
		echo "if {[lsearch [cellname list topcells] {${CELL_NAME}}] < 0} {"
		echo "    set _fp [open {${CELL_MISMATCH_MARKER}} w]"
		echo "    puts \$_fp [cellname list topcells]"
		echo "    close \$_fp"
		echo "    quit -noprompt"
		echo "}"
		echo "load ${CELL_NAME}"
	} >> "$EXT_SCRIPT"
fi

# the layout is flattened so the PEX netlist is flat, the flat copy gets the PEX subcircuit name
{
	echo "select top cell"
	echo "flatten ${CELL_NAME}_flat"
	echo "load ${CELL_NAME}_flat"
	echo "cellname delete ${CELL_NAME}"
	echo "cellname rename ${CELL_NAME}_flat ${CELL_NAME_PEX}"
	echo "select top cell"
	echo "extract path $RESDIR"
	echo "ext2spice lvs"
} >> "$EXT_SCRIPT"

if [ "$EXT_MODE" -eq 1 ] || [ "$EXT_MODE" -eq 2 ]; then
	{
		[ "$EXT_MODE" -eq 1 ] && echo "extract no coupling"
		echo "extract all"
	} >> "$EXT_SCRIPT"
fi

if [ "$EXT_MODE" -eq 3 ]; then
	{
		# these settings replace the deprecated `extresist tolerance`, which Magic now ignores with a warning.
		# they default to Magic's own defaults and can be overridden with -t/-r/-y (see usage).

		# minimum coarse end-to-end resistance (mOhm) a net must exceed before it is considered for resistance extraction
		echo "extresist threshold $EXT_THRESHOLD"
		# delay-based (ps) output gating applied after extraction, 0 gates on the recalculated resistance via the threshold instead
		echo "extresist mindelay $EXT_MINDELAY"
		# simplification value (mOhm), resistors below this are merged
		echo "extresist minres $EXT_MINRES"
		echo "extract do resistance"
		echo "extract do unique"
		echo "extract all"
		echo "ext2spice extresist on"
	} >> "$EXT_SCRIPT"
fi

{
	echo "ext2spice cthresh 0.01"
	echo "ext2spice -p $RESDIR -o $NETLIST_PEX.tmp"
	echo "quit -noprompt"
} >> "$EXT_SCRIPT"

# extract the PEX netlist from the layout with Magic
# --------------------------------------------------

if [ $DEBUG -eq 0 ]; then
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT" \
		> "$PEX_LOG" 2>&1
else
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT" \
		2>&1 | tee "$PEX_LOG"
fi

# GDS top cell did not match the file name (marker written by Magic above), report the specific cause instead of the generic error below
if [ -f "$CELL_MISMATCH_MARKER" ]; then
	echo "[ERROR] GDS top cell does not match <$CELL_NAME>!"
	echo "[ERROR] GDS top cell(s) found: <$(cat "$CELL_MISMATCH_MARKER")>."
	echo "[ERROR] Rename the layout file/cell so they match, then re-run."
	rm -f "$CELL_MISMATCH_MARKER"
	[ -n "$TMP_GDS" ] && rm -f "$TMP_GDS"
	[ -n "$TMP_MAG_DIR" ] && rm -rf "$TMP_MAG_DIR"
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"
	exit $ERR_GENERAL
fi

if [ ! -f "$NETLIST_PEX.tmp" ]; then
	echo "[ERROR] No PEX netlist produced, see <$PEX_LOG>!"
	[ -n "$TMP_GDS" ] && rm -f "$TMP_GDS"
	[ -n "$TMP_MAG_DIR" ] && rm -rf "$TMP_MAG_DIR"
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"
	exit $ERR_GENERAL
fi

# prepend a header with the run settings, this becomes the final netlist
DATE=$(date)
HEADER="* PEX produced on $DATE using $0 with m=$EXT_MODE and s=$SUBCIRCUIT"
[ "$EXT_MODE" -eq 3 ] && HEADER="$HEADER (extresist threshold=$EXT_THRESHOLD mOhm, minres=$EXT_MINRES mOhm, mindelay=$EXT_MINDELAY ps)"
{
	echo "$HEADER"
	cat "$NETLIST_PEX.tmp"
} > "$NETLIST_PEX"
rm -f "$NETLIST_PEX.tmp"

# defensive cleanup, should the in-Magic rename above not have taken effect the flattened cell may still appear as "<cell>_flat" in the netlist.
# Replace only that exact token (regex-escaped) with the intended subcircuit name, a global s/_flat//g would corrupt any legitimate name that happens to contain "_flat" (e.g. a port "vout_flat").
_flat_search=$(printf '%s' "${CELL_NAME}_flat" | sed 's/[][\.*^$/]/\\&/g')
_flat_replace=$(printf '%s' "$CELL_NAME_PEX" | sed 's/[&/\]/\\&/g')
sed -i "s/${_flat_search}/${_flat_replace}/g" "$NETLIST_PEX"

# -s 0: strip the top-level subcircuit wrapper here in the shell. The in-Magic option for this
# (ext2spice subcircuits top off) is overridden while hierarchical output is on, and turning the
# hierarchy off changes the extracted parasitics. Removing the two wrapper lines afterwards keeps
# the netlist content identical to a -s 1 run. The netlist is flat, so exactly one wrapper exists.
if [ "$SUBCIRCUIT" -eq 0 ]; then
	sed -i '/^\.subckt[[:space:]]/Id' "$NETLIST_PEX"
	sed -i '/^\.ends/Id' "$NETLIST_PEX"
fi

# cleanup
# -------

# Magic writes its intermediate files into the result dir (via `extract path`), so remove them, plus the decompressed temp copies
rm -f "$RESDIR"/*.ext
[ -n "$TMP_GDS" ] && rm -f "$TMP_GDS"
[ -n "$TMP_MAG_DIR" ] && rm -rf "$TMP_MAG_DIR"
if [ "$EXT_MODE" -eq 3 ]; then
	rm -f "$RESDIR"/*.nodes
	rm -f "$RESDIR"/*.sim
fi
[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

echo "[INFO] PEX ($EXT_MODE_TEXT) done, the extracted SPICE netlist is <$NETLIST_PEX>."
echo "[DONE] Bye!"
