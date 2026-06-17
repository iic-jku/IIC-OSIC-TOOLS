#!/bin/bash
# ========================================================================
# PEX (Parasitic Extraction) Script for Open-Source IC Design
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
# Usage: sak-pex.sh [-d] [-m mode] [-s mode] [-n <subcktname>] [-w <workdir>]
#                   [-t <threshold>] [-r <minres>] [-y <mindelay>] <cellname>
#        -m  Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)
#        -s  Subcircuit definition (1 = include [default], 0 = no subcircuit)
#        -n  Name of PEX subcircuit (default: <cellname>)
#        -w  Use <workdir> to store result files (default: current dir)
#        -t  full-RC: extresist threshold in mOhm (default: 10000 = 10 Ohm)
#        -r  full-RC: extresist minres in mOhm (default: 1000 = 1 Ohm)
#        -y  full-RC: extresist mindelay in ps (default: 1; 0 = gate by resistance)
#        -d  Enable debug information
#
#        <cellname> may be a cell name or a layout file; accepted layout
#        formats are .mag, .mag.gz, .gds, and .gds.gz
#        NOTE: for GDS input the top cell must be named like the file (<cellname>). Otherwise the script aborts.
#
# Example: sak-pex.sh -m 3 -t 5000 -r 500 -y 2 -n mycell_pex -w ./results mycell.gds
# ========================================================================

ERR_GENERAL=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_WRONG_MODE=4
ERR_CMD_NOT_FOUND=5
ERR_PDK_NOT_SUPPORTED=6

if [ $# -eq 0 ]; then
	echo
	echo "PEX script using Magic (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-m mode] [-s mode] [-n <subcktname>] [-w <workdir>]"
	echo "       [-t <threshold>] [-r <minres>] [-y <mindelay>] <cellname>"
	echo
	echo "       -m Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)"
	echo "       -s Subcircuit definition in PEX netlist (1 = include subcircuit definition [default], 0 = no subcircuit)"
	echo "       -n name of PEX subcircuit (default is <cellname>)"
	echo "       -w Set <workdir> working directory"
	echo "       -t full-RC only: extresist threshold in mOhm (default 10000 = 10 Ohm)"
	echo "       -r full-RC only: extresist minres in mOhm (default 1000 = 1 Ohm)"
	echo "       -y full-RC only: extresist mindelay in ps (default 1; 0 = gate by resistance instead of delay)"
	echo "       -d Enable debug information"
	echo
	echo "       <cellname> may be a cell name or a layout file (.mag, .mag.gz, .gds, .gds.gz)"
	echo "       NOTE: for GDS input the top cell must be named like the file (<cellname>)"
	echo
	exit $ERR_NO_PARAM
fi

# Set the default behavior
# ------------------------

DEBUG=0
GDS_MODE=0
EXT_MODE=2
SUBCIRCUIT=1
RESDIR=$PWD
CELL_NAME_SET=0

# full-RC (extresist) defaults, matching magic's own defaults
EXT_THRESHOLD=10000	# mOhm: coarse end-to-end resistance gating extraction
EXT_MINRES=1000		# mOhm: resistors below this are merged (simplification)
EXT_MINDELAY=1		# ps: delay-based output gating (0 = gate by resistance)

# Check flags
# -----------

while getopts "m:s:w:n:t:r:y:d" flag; do
	case $flag in
		m)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -m is set to <$OPTARG>."
			EXT_MODE=${OPTARG}
			;;
		s)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -s is set to <$OPTARG>."
			SUBCIRCUIT=${OPTARG}
			;;
		t)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -t is set to <$OPTARG>."
			EXT_THRESHOLD=${OPTARG}
			;;
		r)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -r is set to <$OPTARG>."
			EXT_MINRES=${OPTARG}
			;;
		y)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -y is set to <$OPTARG>."
			EXT_MINDELAY=${OPTARG}
			;;
		w)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -w is set to <$OPTARG>."
			RESDIR=$(realpath "$OPTARG")
			;;
		n)
			[ $DEBUG -eq 1 ] && echo "[INFO] Flag -n is set to <$OPTARG>."
			CELL_NAME_SET=1
			CELL_NAME_PEX=${OPTARG}
			;;	
		d)
			echo "[INFO] DEBUG is enabled."
			DEBUG=1
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# Check that the mode is an integer and in a valid range
# ------------------------------------------------------

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

# Check that the full-RC extresist parameters are non-negative integers
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

# Check if the PDK is already supported by this script
# ----------------------------------------------------

if echo "$PDK" | grep -q -i "sky130"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] sky130 PDK selected"
elif echo "$PDK" | grep -q -i "gf180mcu"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] gf180mcu PDK selected"
elif echo "$PDK" | grep -q -i "ihp-sg13g2"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13g2 PDK selected"
elif echo "$PDK" | grep -q -i "ihp-sg13cmos5l"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ihp-sg13cmos5l PDK selected"
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi

# Check if the input file exists
# ------------------------------

if [ -z "$1" ]; then
	echo "[ERROR] No cellname provided!"
	exit $ERR_FILE_NOT_FOUND
elif [ -f "$1" ]; then
	CELL_LAY="$1"
elif [ -f "$1.mag" ]; then
	CELL_LAY="$1.mag"
elif [ -f "$1.mag.gz" ]; then
	CELL_LAY="$1.mag.gz"
elif [ -f "$1.gds" ]; then
	CELL_LAY="$1.gds"
	GDS_MODE=1
elif [ -f "$1.gds.gz" ]; then
	CELL_LAY="$1.gds.gz"
	GDS_MODE=1
else
	echo "[ERROR] Layout $CELL_LAY not found!"
    exit $ERR_FILE_NOT_FOUND
fi

[ $DEBUG -eq 1 ] && echo "[INFO] CELL_LAY=$CELL_LAY"

# Define useful variables
# -----------------------

# Derive the cell name by stripping only the known layout extension, so that cell names which themselves contain dots (e.g. "my.cell.mag") are preserved.
CELL_BASE=$(basename "$CELL_LAY")
case "$CELL_BASE" in
	*.mag.gz)	CELL_NAME=${CELL_BASE%.mag.gz} ;;
	*.gds.gz)	CELL_NAME=${CELL_BASE%.gds.gz} ;;
	*.mag)		CELL_NAME=${CELL_BASE%.mag} ;;
	*.gds)		CELL_NAME=${CELL_BASE%.gds} ;;
	*)		CELL_NAME=$CELL_BASE ;;
esac

EXT_SCRIPT="$RESDIR/pex_$CELL_NAME.tcl"
NETLIST_PEX="$RESDIR/$CELL_NAME.pex.spice"

# GDS only: magic creates this marker if the GDS top cell is not named like the file. The shell checks for it after the run to report a clear error.
CELL_MISMATCH_MARKER="$RESDIR/pex_$CELL_NAME.cellmismatch"
if [ $CELL_NAME_SET -eq 0 ]; then
	CELL_NAME_PEX=${CELL_NAME}
fi

# Make sure the result directory exists (e.g. when set via -w)
[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"

# Check if gzipped MAG file
# -------------------------

# magic's `load` cannot read a gzipped .mag, so unpack it first. The unpacked file must keep the cell name (<cell>.mag) so magic loads it as CELL_NAME. A private temp dir is used to keep that name without clobbering anything.
TMP_MAG_DIR=""
if [[ "$CELL_LAY" == *"mag.gz" ]]; then
	TMP_MAG_DIR="$RESDIR/.pextmp_${CELL_NAME}_$$"
	mkdir -p "$TMP_MAG_DIR"
	gunzip -c "$CELL_LAY" > "$TMP_MAG_DIR/${CELL_NAME}.mag"
	CELL_LAY="$TMP_MAG_DIR/${CELL_NAME}.mag"
fi

# Check if GDS file
# -----------------

# Decompress a gzipped GDS into the result dir under a cell-specific name (not a fixed name in the current dir) to avoid clobbering files there or colliding between runs. TMP_GDS is removed again during cleanup.
TMP_GDS=""
if [[ "$CELL_LAY" == *"gds.gz" ]]; then
	TMP_GDS="$RESDIR/${CELL_NAME}.pextmp.gds"
	gunzip -c "$CELL_LAY" > "$TMP_GDS"
	CELL_LAY="$TMP_GDS"
fi
if [[ "$CELL_LAY" == *"gds" ]]; then
	GDS_MODE=1
	[ $DEBUG = 1 ] && echo "[INFO] GDS mode is selected."	
fi

# Generate extract script for magic
# ---------------------------------

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
	# We read a .gds/.gds.gz view. Magic loads the cell named after the file (CELL_NAME). If the GDS top cell differs, it would silently load an empty cell. So, in this same run, check whether CELL_NAME is a top cell and, if not, write the found top cells to the marker and quit before extracting.
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
	if [ "$EXT_MODE" -eq 1 ]; then
		EXT_MODE_TEXT="C-decoupled"
	elif [ "$EXT_MODE" -eq 2 ]; then
		EXT_MODE_TEXT="C-coupled"
	else
		echo "[ERROR] Illegal branch!"
		exit $ERR_GENERAL
	fi
	
	{
		[ "$EXT_MODE" -eq 1 ] && echo "extract no coupling"
		echo "extract all"
	} >> "$EXT_SCRIPT"
fi

if [ "$EXT_MODE" -eq 3 ]; then
	# Extraction mode RC
	EXT_MODE_TEXT="full-RC"
	{
		# The following lines replace the deprecated `extresist tolerance` (now ignored with a warning).
		# See netgen issue #106: https://github.com/RTimothyEdwards/netgen/issues/106
		# Defaults and can be overridden with -t/-r/-y (see usage).

		# Minimum coarse end-to-end resistance (mOhm) a net must exceed before it is considered for resistance extraction.
		echo "extresist threshold $EXT_THRESHOLD"

		# Delay-based (ps) output gating applied after extraction. Setting it to 0 gates on the recalculated resistance via `threshold` instead.
		echo "extresist mindelay $EXT_MINDELAY"

		# "Simplification value" (mOhm): resistors below this are merged.
		echo "extresist minres $EXT_MINRES"
		echo "extract do resistance"
		echo "extract do unique"
		echo "extract all"
		echo "ext2spice extresist on"
	} >> "$EXT_SCRIPT"
fi

{
	echo "ext2spice cthresh 0.01"	
	[ "$SUBCIRCUIT" -eq 0 ] && echo "ext2spice subcircuit top off"
	echo "ext2spice -p $RESDIR -o $NETLIST_PEX.tmp"
	echo "quit -noprompt"
} >> "$EXT_SCRIPT"

# Check if commands exist in the path
# -----------------------------------

if [ ! -x "$(command -v magic)" ]; then
   	echo "[ERROR] magic could not be found!"
   	exit $ERR_CMD_NOT_FOUND
fi

# Extract SPICE netlist from layout with magic
# --------------------------------------------
echo "[INFO] Running PEX using magic..."

# Drop any stale marker so it only reflects this run.
rm -f "$CELL_MISMATCH_MARKER"

if [ $DEBUG -eq 0 ]; then
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT" \
		> /dev/null 2> /dev/null
else
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		"$EXT_SCRIPT"
fi

# GDS top cell did not match the file name (marker written by magic above): report the specific cause instead of the generic "no file" error below.
if [ -f "$CELL_MISMATCH_MARKER" ]; then
	echo "[ERROR] GDS top cell does not match the file name <$CELL_NAME>!"
	echo "[ERROR] GDS top cell(s) found: <$(cat "$CELL_MISMATCH_MARKER")>."
	echo "[ERROR] Rename the file or the GDS top cell so they match, then re-run."
	rm -f "$CELL_MISMATCH_MARKER"
	exit $ERR_GENERAL
fi

if [ ! -f "$NETLIST_PEX.tmp" ]; then
	echo "[ERROR] No PEX file produced, something went wrong!"
	exit $ERR_GENERAL
else
	DATE=$(date)
	HEADER="* PEX produced on $DATE using $0 with m=$EXT_MODE and s=$SUBCIRCUIT"
	[ "$EXT_MODE" -eq 3 ] && HEADER="$HEADER (extresist threshold=$EXT_THRESHOLD mOhm, minres=$EXT_MINRES mOhm, mindelay=$EXT_MINDELAY ps)"
	{
		echo "$HEADER"
		cat "$NETLIST_PEX.tmp"	
	} > "$NETLIST_PEX"
	rm -f "$NETLIST_PEX.tmp"

	# Defensive cleanup: should the in-magic `cellname rename` above not have taken effect, the flattened cell may still appear as "<cell>_flat" in the netlist. Replace only that exact token (regex-escaped) with the intended subcircuit name, instead of a global s/_flat//g which would corrupt any legitimate name that happens to contain "_flat" (e.g. a port "vout_flat").
	_flat_search=$(printf '%s' "${CELL_NAME}_flat" | sed 's/[][\.*^$/]/\\&/g')
	_flat_replace=$(printf '%s' "$CELL_NAME_PEX" | sed 's/[&/\]/\\&/g')
	sed -i "s/${_flat_search}/${_flat_replace}/g" "$NETLIST_PEX"
fi

# Cleanup
# -------
# Magic writes its intermediate files into the result dir (via `extract path`), so remove them from there, plus the temporary decompressed GDS if any.
rm -f "$RESDIR"/*.ext
[ -n "$TMP_GDS" ] && rm -f "$TMP_GDS"
[ -n "$TMP_MAG_DIR" ] && rm -rf "$TMP_MAG_DIR"
if [ "$EXT_MODE" -eq 3 ]; then
	rm -f "$RESDIR"/*.nodes
	rm -f "$RESDIR"/*.ext
	rm -f "$RESDIR"/*.sim
	rm -f "$RESDIR"/*.res.ext
fi
[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

# Finished
# --------
echo "[DONE] PEX ($EXT_MODE_TEXT) done, extracted SPICE netlist is <$NETLIST_PEX>."
