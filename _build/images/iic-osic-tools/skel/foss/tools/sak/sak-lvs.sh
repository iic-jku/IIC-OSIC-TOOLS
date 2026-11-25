#!/bin/sh
# ========================================================================
# LVS (Layout-vs-Schematic) Script for Open-Source IC Design
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
# Usage: sak-lvs.sh [--json] [-d] [-m|-k|-b] [-H] [-F <cells>] [-J <nets>]... [-W] [-w <workdir>] [-s <schematic> -l <layout> -c <cellname> | <cellname>]
#        -m  Run Magic+Netgen LVS (default)
#        -k  Run KLayout LVS
#        -b  Run Magic+Netgen and KLayout LVS
#        -H  Magic+Netgen: extract the layout hierarchically, so that Netgen compares cell by cell (a chip)
#        -F  Magic+Netgen: comma-separated GDS cells that Magic reads flat into their parents
#        -J  KLayout: comma-separated nets that the netlist joins into its first one, can be repeated
#        -W  KLayout: the layout top cell is a wrapper without labels around the design (a fill wrapper), a missing pad label passes, so check the design cell too
#        -s  Use this <schematic> (xschem .sch schematic, SPICE/CDL netlist, or Verilog netlist)
#        -l  Use this <layout> view
#        -c  Name of <topcell>
#        -w  Use <workdir> to store result files (default: current dir)
#        -d  Enable debug information
#        --json  Print one JSON object with the result on stdout, all messages go to stderr (see sak-report.py)
# ========================================================================

ERR_LVS_MISMATCH=1
ERR_FILE_NOT_FOUND=2
ERR_NO_PARAM=3
ERR_NO_VAR=4
ERR_NO_RESULT=5
ERR_PDK_NOT_SUPPORTED=6
ERR_UNKNOWN_FILE=7
ERR_CMD_NOT_FOUND=8

# --json: print one JSON object on stdout and send every other message to stderr
# -------------------------------------------------------------------------------

JSON=0
JSON_DONE=0
JSON_REPORTS=""
# take --json out of the arguments, the others keep their order and quoting
for _arg in "$@"; do
	shift
	if [ "$_arg" = "--json" ]; then
		JSON=1
	else
		set -- "$@" "$_arg"
	fi
done

# a run that ends without a result object (usage, missing input, failed tool) prints the error object with the exit code of the script.
# Its error text is JSON_ERROR if set, else a short reason derived from the exit code (the full message is on stderr).
JSON_ERROR=""
json_error() {
	_rc=$?
	[ "$JSON_DONE" -eq 1 ] && return
	_reason=$JSON_ERROR
	if [ -z "$_reason" ]; then
		case "$_rc" in
			"$ERR_LVS_MISMATCH")	_reason="LVS mismatch" ;;
			"$ERR_FILE_NOT_FOUND")	_reason="input file not found" ;;
			"$ERR_NO_PARAM")	_reason="wrong usage or missing parameter" ;;
			"$ERR_NO_VAR")	_reason="parameter or PDK environment variable not set" ;;
			"$ERR_NO_RESULT")	_reason="an LVS run failed or produced no result" ;;
			"$ERR_PDK_NOT_SUPPORTED")	_reason="PDK not supported" ;;
			"$ERR_UNKNOWN_FILE")	_reason="unsupported file format" ;;
			"$ERR_CMD_NOT_FOUND")	_reason="a required tool was not found" ;;
			*)	_reason="sak-lvs.sh ended with exit code $_rc" ;;
		esac
	fi
	# JSON string: control characters become spaces, backslash and double quote are escaped
	_reason=$(printf '%s' "$_reason" | tr '\000-\037' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')
	printf '{"schema": 1, "tool": "sak-lvs", "status": "error", "error": "%s", "exit_code": %d, "input": []}\n' "$_reason" "$_rc" >&3
}

if [ "$JSON" -eq 1 ]; then
	exec 3>&1 1>&2
	trap json_error EXIT
fi

# print the result object for the report files collected in JSON_REPORTS (one path per line), compared against the layout <$1> for staleness
json_result() {
	_layout=$1
	_ifs=$IFS
	IFS='
'
	set -f
	# shellcheck disable=SC2086
	set -- $JSON_REPORTS
	IFS=$_ifs
	set +f
	_json=$(sak-report.py --json --tool sak-lvs --newer-than "$_layout" "$@")
	_rc=$?
	# 0 and 1 are the verdict of sak-report.py, anything else means it could not read a report (its message is on stderr)
	if [ "$_rc" -gt 1 ] || [ -z "$_json" ]; then
		_msg=$(printf '%s' "$_json" | python3 -c 'import json, sys; print(json.load(sys.stdin)["error"])' 2>/dev/null)
		JSON_ERROR="sak-report.py could not summarize the reports (exit code $_rc)${_msg:+: $_msg}"
		echo "[ERROR] sak-report.py could not summarize the reports!"
		exit $ERR_NO_RESULT
	fi
	# the exit code of this script follows its own verdict, so a result that contradicts it is not printed
	_own=1
	[ "$LVS_CLEAN" -eq 1 ] && _own=0
	if [ "$_rc" -ne "$_own" ]; then
		_seen=findings
		[ "$_rc" -eq 0 ] && _seen=clean
		_found=findings
		[ "$_own" -eq 0 ] && _found=clean
		JSON_ERROR="sak-report.py reads the reports as $_seen, but sak-lvs.sh found $_found"
		echo "[ERROR] $JSON_ERROR!"
		return
	fi
	printf '%s\n' "$_json" >&3
	JSON_DONE=1
}

if [ $# -eq 0 ]; then
	echo
	echo "LVS script for Magic+Netgen and KLayout (ICD@JKU)"
	echo
	echo "Usage: $0 [--json] [-d] [-m|-k|-b] [-H] [-F <cells>] [-J <nets>]... [-W] [-w <workdir>] [-s <schematic>|<netlist> -l <layout> -c <cellname> | <cellname>]"
	echo
	echo "       Specify <cellname> to use for schematic and layout, resolved against the"
	echo "       current dir using default name prefixes (.sch|.spice|.spc|.cdl|.v|.mag|"
	echo "       .mag.gz|.gds|.gds.gz|.klay.gds). When no <cellname> is specified use -s,"
	echo "       -l, and -c to point to the corresponding files and name the topcell."
	echo
	echo "       -m Run Magic+Netgen LVS (default, not for ics55 and asap7, which have no Magic technology)"
	echo "       -k Run KLayout LVS"
	echo "       -b Run Magic+Netgen and KLayout LVS"
	echo "       -H Magic+Netgen: extract the layout hierarchically, so that Netgen compares cell by cell"
	echo "       -F Magic+Netgen: comma-separated GDS <cells> that Magic reads flat into their parents, for cells"
	echo "          that take an implant or well from outside (the flat mode alone does not fix those)"
	echo "       -J KLayout: comma-separated <nets> that the netlist joins into its first one (repeatable),"
	echo "          their port mismatch on the layout net that carries all their labels is accepted"
	echo "       -W KLayout: the layout top cell is a wrapper without labels around the design, the port"
	echo "          mismatches of its unnamed nets and of pad nets named <instance>.<label> are accepted."
	echo "          A pad without its label looks like an unnamed net, so check the design cell itself too"
	echo "       -H, -F, -J and -W of an engine that -b drops are ignored with a warning"
	echo "       -s Use this <schematic> (xschem .sch schematic, SPICE/CDL netlist, or Verilog netlist)"
	echo "       -l Use this <layout> view"
	echo "       -c Name of <topcell>"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -d Enable debug information"
	echo "       --json Print one JSON object with the result on stdout, all messages go to stderr"
	echo
	exit $ERR_NO_PARAM
fi

# set the default behavior
# ------------------------

DEBUG=0
RESDIR=$PWD
CELLS_GIVEN=0
RUN_MAGIC=1
RUN_KLAYOUT=0
# -H, -F, -J and -W, see the usage
HIER=0
FLAT_CELLS=""
JOINS=""
WRAPPER=0
# format of a directly provided netlist (via -s or auto-derive): "spice" (Magic+Netgen) or "cdl" (KLayout). Stays empty for a .sch schematic, which is netlisted per engine on the fly.
NETLIST_FORMAT=""

# check flags
# -----------

while getopts "mkbs:l:w:c:dHF:J:W" flag; do
	case $flag in
		H)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -H is set."
			HIER=1
			;;
		F)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -F is set to <$OPTARG>."
			if [ -z "$OPTARG" ]; then
				echo "[ERROR] -F needs at least one cell name!"
				exit $ERR_NO_PARAM
			fi
			FLAT_CELLS=$OPTARG
			;;
		J)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -J is set to <$OPTARG>."
			case "$OPTARG" in
				*,*) ;;
				*)
					echo "[ERROR] -J needs at least two comma-separated net names, got <$OPTARG>!"
					exit $ERR_NO_PARAM ;;
			esac
			# one group per line
			JOINS="${JOINS:+$JOINS
}$OPTARG"
			;;
		W)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -W is set."
			WRAPPER=1
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
		w)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -w is set to <$OPTARG>."
			# -m so a not-yet-existing (multi-level) workdir still resolves. It is created below.
			RESDIR=$(realpath -m "$OPTARG")
			;;
		s)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -s is set to <$OPTARG>."
			CELL_SCH=$(realpath "$OPTARG")
			# match the file extension only, not an occurrence somewhere in the path
			case "$CELL_SCH" in
				*.sch)
					VERILOG_MODE=0
					SPICE_MODE=0
					;;
				*.spice|*.spc)
					VERILOG_MODE=0
					SPICE_MODE=1
					NETLIST_FORMAT=spice
					;;
				*.cdl)
					VERILOG_MODE=0
					SPICE_MODE=1
					NETLIST_FORMAT=cdl
					;;
				*.v)
					VERILOG_MODE=1
					SPICE_MODE=0
					# the Verilog LVS path uses $CELL_V (auto-mode sets it too)
					CELL_V="$CELL_SCH"
					;;
				*)
					echo "[ERROR] Unknown file format of <$CELL_SCH>!"
					exit $ERR_UNKNOWN_FILE
					;;
			esac
			CELLS_GIVEN=1
			;;
		l)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -l is set to <$OPTARG>."
			CELL_LAY=$(realpath "$OPTARG")
			# match the file extension only, not an occurrence somewhere in the path
			case "$CELL_LAY" in
				*.gds|*.gds.gz)
					GDS_MODE=1
					;;
				*.mag|*.mag.gz)
					GDS_MODE=0
					;;
				*)
					echo "[ERROR] Unknown file format of <$CELL_LAY>!"
					exit $ERR_UNKNOWN_FILE
					;;
			esac
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
# the engines asked for, before the checks below drop one: -H, -F, -J and -W of a dropped engine are ignored with a warning, as -b does
REQ_MAGIC=$RUN_MAGIC
REQ_KLAYOUT=$RUN_KLAYOUT

# check if all 3 parameters -s -l and -c are specified
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
if [ -z "$STD_CELL_LIBRARY" ]; then
	echo "[ERROR] Variable STD_CELL_LIBRARY not set!"
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
elif echo "$PDK" | grep -q -i "^ics55"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] ics55 PDK selected."
elif echo "$PDK" | grep -q -i "asap7"; then
	[ $DEBUG -eq 1 ] && echo "[INFO] asap7 PDK selected."
else
	echo "[ERROR] The PDK $PDK is not yet supported!"
	exit $ERR_PDK_NOT_SUPPORTED
fi


# check if files exist, look into usual directories
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
		elif [ -f "$1.spice" ]; then
			CELL_SCH="$1.spice"
			SPICE_MODE=1
			NETLIST_FORMAT=spice
		elif [ -f "$1.spc" ]; then
			CELL_SCH="$1.spc"
			SPICE_MODE=1
			NETLIST_FORMAT=spice
		elif [ -f "$1.cdl" ]; then
			CELL_SCH="$1.cdl"
			SPICE_MODE=1
			NETLIST_FORMAT=cdl
		else
			echo "[ERROR] No schematic/SPICE/CDL netlist/Verilog file for <$1> found!"
			exit $ERR_FILE_NOT_FOUND
		fi
	fi

	# derive the layout file from the cellname, resolved against the current dir.
	# The list encodes the lookup priority, the magic view is found before the GDS views.
	CELL_LAY=""
	for _lay in "$1.mag" "$1.mag.gz" "$1.gds" "$1.gds.gz" "$1.klay.gds"; do
		if [ -f "$_lay" ]; then
			CELL_LAY="$_lay"
			break
		fi
	done
	if [ -z "$CELL_LAY" ]; then
		echo "[ERROR] No layout file for <$1> found!"
		exit $ERR_FILE_NOT_FOUND
	fi
	case "$CELL_LAY" in
		*.mag|*.mag.gz)	GDS_MODE=0 ;;
		*)		GDS_MODE=1 ;;
	esac
fi

# make the layout path absolute so it still resolves after we cd into $RESDIR
# --------------------------------------------------------------------------

CELL_LAY=$(realpath "$CELL_LAY")
# a decompressed copy replaces CELL_LAY below, the result files are compared against the layout as given
CELL_LAY_GIVEN="$CELL_LAY"

[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 1 ] && echo "[INFO] Using Verilog file <$CELL_V>."
[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 0 ] && [ "$SPICE_MODE" -eq 0 ] && echo "[INFO] Using schematic file <$CELL_SCH>."
[ $DEBUG -eq 1 ] && [ "$VERILOG_MODE" -eq 0 ] && [ "$SPICE_MODE" -eq 1 ] && echo "[INFO] Using SPICE/CDL netlist file <$CELL_SCH>."
[ $DEBUG -eq 1 ] && echo "[INFO] Using layout file <$CELL_LAY>."

# check that the required tools are available
# -------------------------------------------

if [ "$RUN_MAGIC" -eq 1 ]; then
	for cmd in magic netgen; do
		if [ ! -x "$(command -v "$cmd")" ]; then
			echo "[ERROR] $cmd could not be found!"
			exit $ERR_CMD_NOT_FOUND
		fi
	done
fi

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	for cmd in klayout python3; do
		if [ ! -x "$(command -v "$cmd")" ]; then
			echo "[ERROR] $cmd could not be found!"
			exit $ERR_CMD_NOT_FOUND
		fi
	done
fi

# xschem is only needed to netlist a .sch schematic
if [ "$VERILOG_MODE" -eq 0 ] && [ "$SPICE_MODE" -eq 0 ]; then
	if [ ! -x "$(command -v xschem)" ]; then
		echo "[ERROR] xschem could not be found!"
		exit $ERR_CMD_NOT_FOUND
	fi
fi

# ics55 and asap7 have no Magic technology or Netgen setup, so Magic+Netgen LVS is dropped when KLayout LVS also runs and is an error otherwise.
# ----------------------------------------------------------------------------------------------

if [ "$RUN_MAGIC" -eq 1 ] && echo "$PDK" | grep -q -i -E "^ics55|asap7"; then
	if [ "$RUN_KLAYOUT" -eq 1 ]; then
		echo "[WARNING] Magic+Netgen LVS is not available for $PDK, running KLayout LVS only."
		RUN_MAGIC=0
	else
		echo "[ERROR] Magic+Netgen LVS is not available for $PDK, use -k for KLayout LVS!"
		exit $ERR_PDK_NOT_SUPPORTED
	fi
fi

# KLayout LVS is implemented for sky130/gf180mcu/ihp-sg13g2/ihp-sg13cmos5l/ics55/asap7 and needs a GDS layout and a schematic/CDL netlist (no Verilog). In each unmet case skip KLayout: warn and continue if Magic+Netgen also runs, otherwise error out.
# ----------------------------------------------------------------------------------------------

if [ "$RUN_KLAYOUT" -eq 1 ] && ! echo "$PDK" | grep -q -i -E "sky130|gf180mcu|ihp-sg13g2|ihp-sg13cmos5l|^ics55|asap7"; then
	if [ "$RUN_MAGIC" -eq 1 ]; then
		echo "[WARNING] KLayout LVS for $PDK not yet supported, running Magic+Netgen LVS only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout LVS for $PDK not yet supported!"
		exit $ERR_PDK_NOT_SUPPORTED
	fi
fi
if [ "$RUN_KLAYOUT" -eq 1 ] && [ "$GDS_MODE" -eq 0 ]; then
	if [ "$RUN_MAGIC" -eq 1 ]; then
		echo "[WARNING] KLayout LVS needs a GDS layout, running Magic+Netgen LVS only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout LVS needs a GDS layout (got <$CELL_LAY>)!"
		exit $ERR_UNKNOWN_FILE
	fi
fi
if [ "$RUN_KLAYOUT" -eq 1 ] && [ "$VERILOG_MODE" -eq 1 ]; then
	if [ "$RUN_MAGIC" -eq 1 ]; then
		echo "[WARNING] KLayout LVS does not support a Verilog netlist, running Magic+Netgen LVS only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout LVS does not support a Verilog netlist!"
		exit $ERR_UNKNOWN_FILE
	fi
fi

# A directly provided netlist is engine-specific: Magic+Netgen needs a SPICE netlist, KLayout needs a CDL netlist (they are netlisted with different xschem flags and are not interchangeable). A .sch is fine for either since the matching netlist is generated on the fly. Skip the incompatible engine: warn and continue if the other engine still runs, otherwise error out.
# ----------------------------------------------------------------------------------------------

if [ "$SPICE_MODE" -eq 1 ] && [ "$NETLIST_FORMAT" = "spice" ] && [ "$RUN_KLAYOUT" -eq 1 ]; then
	if [ "$RUN_MAGIC" -eq 1 ]; then
		echo "[WARNING] KLayout LVS needs a CDL netlist but a SPICE netlist was provided, running Magic+Netgen LVS only."
		RUN_KLAYOUT=0
	else
		echo "[ERROR] KLayout LVS needs a CDL netlist, but a SPICE netlist was provided (<$CELL_SCH>)!"
		exit $ERR_UNKNOWN_FILE
	fi
fi
if [ "$SPICE_MODE" -eq 1 ] && [ "$NETLIST_FORMAT" = "cdl" ] && [ "$RUN_MAGIC" -eq 1 ]; then
	if [ "$RUN_KLAYOUT" -eq 1 ]; then
		echo "[WARNING] Magic+Netgen LVS needs a SPICE netlist but a CDL netlist was provided, running KLayout LVS only."
		RUN_MAGIC=0
	else
		echo "[ERROR] Magic+Netgen LVS needs a SPICE netlist, but a CDL netlist was provided (<$CELL_SCH>)!"
		exit $ERR_UNKNOWN_FILE
	fi
fi

# -H and -F shape the Magic extraction, -J and -W the KLayout verdict, so each needs its engine, and -F a GDS layout
# ----------------------------------------------------------------------------------------------

if { [ "$HIER" -eq 1 ] || [ -n "$FLAT_CELLS" ]; } && [ "$RUN_MAGIC" -eq 0 ]; then
	if [ "$REQ_MAGIC" -eq 1 ]; then
		echo "[WARNING] -H and -F apply to Magic+Netgen LVS, which does not run, so they are ignored."
		HIER=0
		FLAT_CELLS=""
	else
		echo "[ERROR] -H and -F apply to Magic+Netgen LVS, which does not run!"
		exit $ERR_NO_PARAM
	fi
fi
if { [ -n "$JOINS" ] || [ "$WRAPPER" -eq 1 ]; } && [ "$RUN_KLAYOUT" -eq 0 ]; then
	if [ "$REQ_KLAYOUT" -eq 1 ]; then
		echo "[WARNING] -J and -W apply to KLayout LVS, which does not run, so they are ignored."
		JOINS=""
		WRAPPER=0
	else
		echo "[ERROR] -J and -W apply to KLayout LVS, which does not run!"
		exit $ERR_NO_PARAM
	fi
fi
if [ -n "$FLAT_CELLS" ] && [ "$GDS_MODE" -eq 0 ]; then
	echo "[ERROR] -F needs a GDS layout (got <$CELL_LAY>)!"
	exit $ERR_UNKNOWN_FILE
fi
# Each -F name goes braced into the Magic Tcl script, so it may hold no brace or blank, and as for sak-drc.sh -f no negated set [!...], which Magic reads as a plain list of characters.
# A pattern that matches the top cell would flatten it away and leave an empty cell to extract.
if [ -n "$FLAT_CELLS" ]; then
	set -f
	_ifs=$IFS
	IFS=,
	for _cell in $FLAT_CELLS; do
		case "$_cell" in
			""|*" "*|*"	"*|*\{*|*\}*|*\[!*)
				echo "[ERROR] -F takes comma-separated cell names or glob patterns without blanks, braces or a negated set [!...], got <$_cell>!"
				exit $ERR_NO_PARAM ;;
		esac
		# shellcheck disable=SC2254
		case "$TOPCELL" in
			$_cell)
				echo "[ERROR] The -F pattern <$_cell> matches the top cell <$TOPCELL>: Magic would flatten it away! Use a pattern that matches subcells only."
				exit $ERR_NO_PARAM ;;
		esac
	done
	IFS=$_ifs
	set +f
fi

# define useful variables
# -----------------------

# keep the cell name verbatim (basename only) so names containing dots are not truncated
FBASENAME=$(basename "$TOPCELL")
# run dir holding the Magic+Netgen LVS report, log, layout netlist, and generated extract script. It is wiped at the start of each Magic+Netgen run.
MAGIC_RUNDIR="$RESDIR/${FBASENAME}.magic.lvs"
EXT_SCRIPT="$MAGIC_RUNDIR/ext_$FBASENAME.tcl"
NETLIST_SCH="$RESDIR/${FBASENAME}_magic.spice"
NETLIST_LAY="$MAGIC_RUNDIR/$FBASENAME.ext.spc"
NETLIST_KLAYOUT="$RESDIR/${FBASENAME}_klayout.cdl"
LVS_REPORT="$MAGIC_RUNDIR/$FBASENAME.lvs.out"
LVS_LOG="$MAGIC_RUNDIR/$FBASENAME.lvs.log"
# run dir holding the KLayout LVS report(s) (.lvsdb) and log
KLAYOUT_RUNDIR="$RESDIR/${FBASENAME}.klayout.lvs"
KLAYOUT_LOG="$KLAYOUT_RUNDIR/${FBASENAME}.klayout.lvs.log"
# GDS only: magic writes this marker if the GDS top cell is not named like $TOPCELL. It is checked after the run.
CELL_MISMATCH_MARKER="$MAGIC_RUNDIR/ext_$FBASENAME.cellmismatch"
[ ! -d "$RESDIR" ] && mkdir -p "$RESDIR"

# remove old netlists (keep a directly provided netlist that already is the target file)
# --------------------------------------------------------------------------------------

[ -f "$NETLIST_SCH" ] && [ "$CELL_SCH" != "$NETLIST_SCH" ] && rm -f "$NETLIST_SCH"

# decompress gzipped layout views, magic cannot read them directly
# ----------------------------------------------------------------

GZ_TMP=""
case "$CELL_LAY" in
	*.gz)
		if [ "$GDS_MODE" -eq 1 ]; then
			GZ_TMP="$RESDIR/${FBASENAME}.lvstmp.gds"
		else
			GZ_TMP="$RESDIR/${FBASENAME}.lvstmp.mag"
		fi
		[ $DEBUG -eq 1 ] && echo "[INFO] Decompressing <$CELL_LAY> to <$GZ_TMP>."
		gunzip -c "$CELL_LAY" > "$GZ_TMP"
		CELL_LAY="$GZ_TMP"
		;;
esac

# initial checks passed, start working
# ------------------------------------

if [ "$VERILOG_MODE" -eq 0 ]; then
	echo "[INFO] Running LVS of <$CELL_LAY> vs <$CELL_SCH>."
else
	echo "[INFO] Running LVS of <$CELL_LAY> vs <$CELL_V>."
fi

# extract the SPICE netlist from schematic (for Magic+Netgen)
# -----------------------------------------------------------

if [ "$RUN_MAGIC" -eq 1 ] && [ "$VERILOG_MODE" -eq 0 ]; then
	if [ "$SPICE_MODE" -eq 0 ]; then
		echo "[INFO] Extracting SPICE netlist from schematic <$CELL_SCH>..."
		RESDIR_TCL=$(printf '%s' "$RESDIR" | sed 's/[][\\$"]/\\&/g')
		XSCHEMTCL="set spiceprefix 1; set lvs_netlist 0; set top_is_subckt 1; set lvs_ignore 1; set ev_precision 5; set netlist_dir \"$RESDIR_TCL\"; xschem set netlist_name ${FBASENAME}_magic.spice; xschem netlist"
		xschem -s -r -x -q \
			--rcfile "$PDK_ROOT/$PDK/libs.tech/xschem/xschemrc" \
			--command "$XSCHEMTCL" \
			"$CELL_SCH" \
			> /dev/null 2> /dev/null

		if [ ! -f "$NETLIST_SCH" ]; then
			echo "[ERROR] No schematic netlist produced!"
			[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
			exit $ERR_NO_RESULT
		fi

		# if the SPICE netlist instantiates standard cells (any cell defined in the library netlist), append the library so netgen can resolve them
		STD_CELL_SPICE="$PDK_ROOT/$PDK/libs.ref/$STD_CELL_LIBRARY/spice/$STD_CELL_LIBRARY.spice"
		if [ -f "$STD_CELL_SPICE" ] && grep -iE '^\.subckt[[:space:]]' "$STD_CELL_SPICE" | awk '{print $2}' | grep -qiwFf - "$NETLIST_SCH"; then
			# remove the .end, append the standard cell library, add the .end again
			sed -i '/\.end\b/Id' "$NETLIST_SCH"
			cat "$STD_CELL_SPICE" >> "$NETLIST_SCH"
			echo ".end" >> "$NETLIST_SCH"
		fi

		# remove .save statements from xschem (if there are any)
		sed -i '/\.save/d' "$NETLIST_SCH"
	else
		echo "[INFO] Using SPICE/CDL netlist <$CELL_SCH>..."
		# use the provided netlist in place (mirrors the KLayout branch), instead of copying it into the workdir
		NETLIST_SCH="$CELL_SCH"
	fi
fi

# extract the CDL netlist from schematic (for KLayout LVS)
# -------------------------------------------------------
# KLayout LVS uses a CDL netlist (set lvs_netlist 1) while Magic+Netgen uses a SPICE netlist (set lvs_netlist 0). Both keep lvs_ignore 1. A given SPICE/CDL netlist is used as-is.

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	if [ "$SPICE_MODE" -eq 1 ]; then
		NETLIST_KLAYOUT="$CELL_SCH"
	else
		echo "[INFO] Extracting CDL netlist from schematic <$CELL_SCH>..."
		[ -f "$NETLIST_KLAYOUT" ] && rm -f "$NETLIST_KLAYOUT"
		RESDIR_TCL=$(printf '%s' "$RESDIR" | sed 's/[][\\$"]/\\&/g')
		XSCHEMTCL_KLAYOUT="set spiceprefix 1; set lvs_netlist 1; set top_is_subckt 1; set lvs_ignore 1; set ev_precision 5; set netlist_dir \"$RESDIR_TCL\"; xschem set netlist_name ${FBASENAME}_klayout.cdl; xschem netlist"
		xschem -s -r -x -q \
			--rcfile "$PDK_ROOT/$PDK/libs.tech/xschem/xschemrc" \
			--command "$XSCHEMTCL_KLAYOUT" \
			"$CELL_SCH" \
			> /dev/null 2> /dev/null

		if [ ! -f "$NETLIST_KLAYOUT" ]; then
			echo "[ERROR] No KLayout CDL netlist produced!"
			[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
			exit $ERR_NO_RESULT
		fi

		# if the CDL netlist instantiates standard cells (any cell defined in the library netlist), append the library so KLayout can resolve them
		STD_CELL_CDL="$PDK_ROOT/$PDK/libs.ref/$STD_CELL_LIBRARY/cdl/$STD_CELL_LIBRARY.cdl"
		# asap7 keeps the CDL of every threshold flavor in libs.ref/asap7sc7p5t, one file per flavor
		if echo "$PDK" | grep -q -i "asap7"; then
			case "$STD_CELL_LIBRARY" in
				*_lvt)	_vt=L ;;
				*_slvt)	_vt=SL ;;
				*)	_vt=R ;;
			esac
			STD_CELL_CDL="$PDK_ROOT/$PDK/libs.ref/asap7sc7p5t/cdl/asap7sc7p5t_28_${_vt}.cdl"
		fi
		if [ -f "$STD_CELL_CDL" ] && grep -iE '^\.subckt[[:space:]]' "$STD_CELL_CDL" | awk '{print $2}' | grep -qiwFf - "$NETLIST_KLAYOUT"; then
			# remove the .end, append the standard cell library, add the .end again
			sed -i '/\.end\b/Id' "$NETLIST_KLAYOUT"
			cat "$STD_CELL_CDL" >> "$NETLIST_KLAYOUT"
			echo ".END" >> "$NETLIST_KLAYOUT"
		fi
	fi
fi

# ============================================================================
# Magic + Netgen LVS
# ============================================================================

MAGIC_OK=1
MAGIC_PROPERR=0
if [ "$RUN_MAGIC" -eq 1 ]; then

	# remove old result files so the run dir only reflects this run
	rm -rf "$MAGIC_RUNDIR"
	mkdir -p "$MAGIC_RUNDIR"

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
		# -F: Magic sets the device types of a cell when it reads the cell, so a cell that takes an implant or well from its parent or a neighbour extracts wrong.
		# The flatten below comes after the read and does not help, gds flatglob reads the cell flat into its parents.
		# Each name is Tcl source in the script, so it is braced (gds flatglob takes a glob pattern), and the shell must not expand the pattern either.
		set -f
		_ifs=$IFS
		IFS=,
		for _cell in $FLAT_CELLS; do
			[ -n "$_cell" ] && printf 'gds flatglob {%s}\n' "$_cell" >> "$EXT_SCRIPT"
		done
		IFS=$_ifs
		set +f
		# we read a .gds/.gds.gz view. Magic loads the cell named $TOPCELL. If the GDS has no such top cell it would silently load an empty cell and produce a bogus LVS. So check for it first and, if missing, write the found top cells to a marker and quit before extracting.
		{
			echo "gds read $CELL_LAY"
			echo "if {[lsearch [cellname list topcells] {${TOPCELL}}] < 0} {"
			echo "    set _fp [open {${CELL_MISMATCH_MARKER}} w]"
			echo "    puts \$_fp [cellname list topcells]"
			echo "    close \$_fp"
			echo "    quit -noprompt"
			echo "}"
			echo "load $TOPCELL"
		} >> "$EXT_SCRIPT"
	fi

	echo "select top cell" >> "$EXT_SCRIPT"

	# Note 1: Flatten the layout first to avoid magic extracting a device that is nested in a subcircuit of the same name, which breaks netgen pin matching (e.g. an outer `sg13_<dev>` cell containing an inner `<dev>` subcell that collides with the extracted device `<dev>`).
	# See netgen issue #106: https://github.com/RTimothyEdwards/netgen/issues/106
	# We flatten into a uniquely-named cell (${TOPCELL}_flat) to avoid the "flatten <cell> into <cell>" infinite-loop crash noted in that issue.
	# Note 2: This assumes the loaded top cell is named exactly "$TOPCELL". When using -l/-c with a layout whose internal cellname differs, the delete/rename below would not match that cell.
	# Note 3: The flatten is skipped in Verilog mode to preserve hierarchical standard-cell matching: a full flatten would force netgen to flatten the schematic side too, which is slow on large digital designs and loses subcell error localization.
	# Note 4: -H skips it as well. Netgen then compares cell by cell, which a chip of several hundred thousand devices needs to finish.
	if [ "$VERILOG_MODE" -eq 0 ] && [ "$HIER" -eq 0 ]; then
		{
			echo "flatten ${TOPCELL}_flat"
			echo "load ${TOPCELL}_flat"
			echo "cellname delete ${TOPCELL}"
			echo "cellname rename ${TOPCELL}_flat ${TOPCELL}"
			echo "select top cell"
		} >> "$EXT_SCRIPT"
	fi

	{
		echo "extract path $MAGIC_RUNDIR"
		echo "extract no capacitance"
		echo "extract no coupling"
		echo "extract no resistance"
		echo "extract no length"
	} >> "$EXT_SCRIPT"
	# -H: labels that repeat on separate nets of a cell get unique names, except the ports of the top cell (several pads of one supply), as LibreLane's MAGIC_EXT_UNIQUE does
	[ "$HIER" -eq 1 ] && echo "extract unique notopports" >> "$EXT_SCRIPT"
	{
		echo "extract all"
		echo "ext2spice lvs"
	} >> "$EXT_SCRIPT"
	# -H: the top cell as a .subckt also when it has no ports (a fill wrapper). Otherwise ext2spice writes it as bare top-level statements, and Netgen names it after a cell inside it.
	[ "$HIER" -eq 1 ] && echo "ext2spice subcircuit top on" >> "$EXT_SCRIPT"

	if [ "$VERILOG_MODE" -eq 1 ]; then
		# this is needed for the LVS in netgen because the standard cells
		# are not instantiated in the (powered) .v file
		echo "ext2spice subcircuit descend off" >> "$EXT_SCRIPT"
	fi

	{
		echo "ext2spice -p $MAGIC_RUNDIR -o $NETLIST_LAY"
		echo "quit -noprompt"
	} >> "$EXT_SCRIPT"

	# extract SPICE netlist from layout with magic
	# --------------------------------------------

	echo "[INFO] Extracting netlist from layout <$CELL_LAY>..."
	OLDDIR=$PWD && cd "$MAGIC_RUNDIR" || exit $ERR_NO_RESULT
	magic -dnull -noconsole \
		-rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc" \
		 "$EXT_SCRIPT" \
		 > /dev/null 2> /dev/null
	cd "$OLDDIR" || exit $ERR_NO_RESULT

	# GDS top cell did not match the file name (marker written by magic above): report the specific cause instead of the generic error below.
	if [ -f "$CELL_MISMATCH_MARKER" ]; then
		echo "[ERROR] GDS top cell does not match <$TOPCELL>!"
		echo "[ERROR] GDS top cell(s) found: <$(cat "$CELL_MISMATCH_MARKER")>."
		echo "[ERROR] Rename the layout file/cell or use -c so they match, then re-run."
		rm -f "$CELL_MISMATCH_MARKER"
		[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"
		[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
		exit $ERR_NO_RESULT
	fi

	if [ ! -f "$NETLIST_LAY" ]; then
		echo "[ERROR] No layout netlist produced!"
		[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
		exit $ERR_NO_RESULT
	fi

	# now run the LVS using netgen
	# ----------------------------

	NETGEN_SETUP="$PDK_ROOT/$PDK/libs.tech/netgen/${PDK}_setup.tcl"
	# IHP: the xschem symbols write the Monte Carlo switch mm_ok=1 into the SPICE netlist, and the PDK netgen setup compares it as a device property.
	# It does not describe the layout, so netgen gets a setup that sources the PDK setup and then deletes mm_ok from every cell.
	if echo "$PDK" | grep -q -i "^ihp-sg13"; then
		NETGEN_SETUP_PDK="$NETGEN_SETUP"
		NETGEN_SETUP="$MAGIC_RUNDIR/netgen_setup_${FBASENAME}.tcl"
		{
			echo "# Written by sak-lvs.sh: the PDK setup, then mm_ok deleted from every cell."
			echo "source {$NETGEN_SETUP_PDK}"
			echo 'foreach c [cells list -all -circuit1] { catch {property "-circuit1 $c" delete mm_ok} }'
			echo 'foreach c [cells list -all -circuit2] { catch {property "-circuit2 $c" delete mm_ok} }'
		} > "$NETGEN_SETUP"
		echo "[INFO] Netgen ignores mm_ok (setup <$NETGEN_SETUP>)."
	fi

	echo "[INFO] Run netgen..."
	if [ "$VERILOG_MODE" -eq 0 ]; then
		netgen -batch lvs "$NETLIST_LAY $TOPCELL" "$NETLIST_SCH $TOPCELL" \
			"$NETGEN_SETUP" \
			"$LVS_REPORT" > "$LVS_LOG"
	else
		# MAGIC_EXT_USE_GDS=1 makes the netgen PDK setup (${PDK}_setup.tcl) do GDS/device-level LVS and ignore the physical-only tap/fill cells (present in the layout, absent from the .v netlist).
		# It is read by the netgen setup, not magic. On PDKs whose setup ignores it, it has no effect.
		export MAGIC_EXT_USE_GDS=1
		netgen -batch lvs "$NETLIST_LAY $TOPCELL" "$CELL_V $TOPCELL" \
			"$NETGEN_SETUP" \
			"$LVS_REPORT" > "$LVS_LOG"
	fi

	# magic writes its intermediate .ext files into the run dir (via `extract path`), so remove them
	rm -f "$MAGIC_RUNDIR"/*.ext
	[ $DEBUG -eq 0 ] && rm -f "$EXT_SCRIPT"

	if [ ! -f "$LVS_REPORT" ]; then
		echo "[ERROR] No netgen LVS report produced!"
		[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
		exit $ERR_NO_RESULT
	fi
	JSON_REPORTS="$JSON_REPORTS
$LVS_REPORT"
	# netgen exits with 0 even on a mismatch, so the verdict is read from the report: only "Final result: Circuits match uniquely." passes.
	# Differing device parameters (W, L, ...) keep that line, so the property errors of the top cell and the subcells are checked separately.
	grep -q "^Final result: Circuits match uniquely\.$" "$LVS_REPORT" || MAGIC_OK=0
	if grep -q -e "^Property errors were found\." -e "^The following cells had property errors:" "$LVS_REPORT"; then
		MAGIC_OK=0
		MAGIC_PROPERR=1
	fi
fi

# ============================================================================
# KLayout LVS (per PDK deck or run_lvs.py wrapper)
# ============================================================================

# Verdict of the KLayout report <$1> for -J and -W, read from its cross-reference section (the short format the decks write).
# Every circuit pair has to match, and every error that KLayout records inside a pair (it still counts the pair as matched) has to be a port mismatch that -J or -W accepts.
# Prints what fails and returns 1 if anything does.
klayout_xref_verdict() {
	python3 - "$1" "$WRAPPER" "$JOINS" <<'PYEOF'
import re
import sys

path, wrapper = sys.argv[1], sys.argv[2] == "1"
joins = [[n.strip().upper() for n in g.split(",")] for g in sys.argv[3].splitlines() if g.strip()]


def accepted(msg):
    m = re.match(r"Port mismatch '([^']*)' vs\. '([^']*)'$", msg)
    if not m:
        return None
    lay, ref = m.group(1).split(","), m.group(2).upper()
    if wrapper:
        # KLayout flattens the design into the wrapper: inner nets get no name, pad nets <instance>.<label>, one prefix per level
        lay = [re.sub(r"^(\$\d+\.)+", "", n) for n in lay]
        named = [n for n in lay if not re.fullmatch(r"\$I?\d+", n)]
        if not named:
            return "unnamed nets inside the wrapper"
        if all(n.upper() == ref for n in named):
            return "pad nets the wrapper names <instance>.<label>, with the label of the netlist"
        lay = named
    for group in joins:
        if {n.upper() for n in lay} == set(group) and ref == group[0]:
            return "nets joined by -J " + ",".join(group)
    return None


status = {"1": "Match", "W": "MatchWithWarning", "0": "NoMatch", "X": "Mismatch", "S": "Skipped"}
bad, ok, pairs, circuit, xref = [], {}, 0, None, False
with open(path, encoding="utf-8", errors="replace") as fh:
    for ln in fh:
        if ln.startswith("Z("):
            xref = True
        elif xref and re.match(r"\s*M\(E\b", ln):
            e = re.search(r"B\('((?:[^'\\]|\\.)*)'\)", ln)
            msg = re.sub(r"\\(.)", r"\1", e.group(1)) if e else ln.strip()
            why = accepted(msg) if e else None
            if why:
                ok[why] = ok.get(why, 0) + 1
            else:
                bad.append("%s: %s" % (circuit, msg))
        elif xref:
            m = re.match(r" X\((\(\)|\S+) (\(\)|\S+) (\S)", ln)
            if m:
                circuit, pairs = m.group(1), pairs + 1
                st = status.get(m.group(3), m.group(3))
                if st not in ("Match", "MatchWithWarning"):
                    bad.append("%s / %s: %s" % (m.group(1), m.group(2), st))
            elif ln.startswith(" X("):
                circuit, pairs = None, pairs + 1
                bad.append("unparsed circuit pair %s" % ln.strip())
if not pairs:
    print("[ERROR] No circuit pairs found in <%s>!" % path)
    sys.exit(1)
for why, n in sorted(ok.items()):
    print("[INFO] KLayout: %d accepted port mismatches, %s." % (n, why))
if "unnamed nets inside the wrapper" in ok:
    print("[WARNING] KLayout: with -W a pad without its label looks like an unnamed net inside the wrapper. Run the design cell itself without -W to check the labels.")
for b in bad[:40]:
    print("[INFO] KLayout: not matched: " + b)
if len(bad) > 40:
    print("[INFO] KLayout: and %d more, see the report." % (len(bad) - 40))
sys.exit(1 if bad else 0)
PYEOF
}

KLAYOUT_OK=1
if [ "$RUN_KLAYOUT" -eq 1 ]; then
	echo "[INFO] Run KLayout LVS..."
	rm -rf "$KLAYOUT_RUNDIR"
	mkdir -p "$KLAYOUT_RUNDIR"
	# sky130, gf180mcu, ics55 and asap7 run their LVS deck directly. The IHP PDKs use their run_lvs.py wrapper under klayout/tech/lvs.
	if echo "$PDK" | grep -q -i "sky130"; then
		# The sky130 run_lvs.py wrapper is not used because it resolves its deck as $PDK_ROOT/$PDK/sky130.lvs, which does not exist in this installation.
		# convert_subckts and scale: xschem writes sky130 devices as subcircuit calls with W and L in micrometers, without both switches no device matches.
		klayout -b -r "$PDKPATH/libs.tech/klayout/lvs/sky130.lvs" \
			-rd input="$CELL_LAY" \
			-rd top_cell="$TOPCELL" \
			-rd schematic="$NETLIST_KLAYOUT" \
			-rd report="$KLAYOUT_RUNDIR/$FBASENAME.lvsdb" \
			-rd target_netlist="$KLAYOUT_RUNDIR/${FBASENAME}_extracted.cir" \
			-rd run_mode=deep \
			-rd convert_subckts=true \
			-rd scale=true \
			> "$KLAYOUT_LOG" 2>&1
	elif echo "$PDK" | grep -q -i "gf180mcu"; then
		# The gf180mcu run_lvs.py wrapper is not used because it cannot pass check_ports. The deck turns that check on by
		# default and then requires a labelled layout net for every schematic port. It always names the substrate SUB, so a
		# bulk pin such as VPW of an untapped standard cell can never match. check_ports=false keeps the port handling of
		# Magic+Netgen LVS. The other switches below match what the wrapper would pass.
		# The metal stack follows the variant letter of the PDK name (e.g. gf180mcuD -> D), with D as fallback.
		GF180_VARIANT=$(printf '%s' "$PDK" | sed 's/.*[Gg][Ff]180[Mm][Cc][Uu]//' | cut -c1 | tr 'a-z' 'A-Z')
		case "$GF180_VARIANT" in
			A) GF180_STACK="-rd metal_top=30K -rd mim_option=A -rd metal_level=3LM" ;;
			B) GF180_STACK="-rd metal_top=11K -rd mim_option=B -rd metal_level=4LM" ;;
			C) GF180_STACK="-rd metal_top=9K -rd mim_option=B -rd metal_level=5LM" ;;
			*) GF180_STACK="-rd metal_top=11K -rd mim_option=B -rd metal_level=5LM" ;;
		esac
		# shellcheck disable=SC2086
		klayout -b -r "$PDKPATH/libs.tech/klayout/tech/lvs/gf180mcu.lvs" \
			-rd input="$CELL_LAY" \
			-rd topcell="$TOPCELL" \
			-rd schematic="$NETLIST_KLAYOUT" \
			-rd report="$KLAYOUT_RUNDIR/$FBASENAME.lvsdb" \
			-rd target_netlist="$KLAYOUT_RUNDIR/$FBASENAME.cir" \
			-rd run_mode=deep \
			$GF180_STACK \
			-rd poly_res=1k \
			-rd mim_cap=2 \
			-rd spice_net_names=true \
			-rd spice_comments=false \
			-rd check_ports=false \
			> "$KLAYOUT_LOG" 2>&1
	elif echo "$PDK" | grep -q -i "asap7"; then
		# The asap7 deck compares the standard cells inside a design at transistor level, except those whose layout does
		# not reduce to their CDL in KLayout, which it compares as black boxes (KNOWN_MISMATCH in the deck).
		klayout -b -r "$PDKPATH/libs.tech/klayout/lvs/asap7.lvs" \
			-rd input="$CELL_LAY" \
			-rd topcell="$TOPCELL" \
			-rd schematic="$NETLIST_KLAYOUT" \
			-rd report="$KLAYOUT_RUNDIR/$FBASENAME.lvsdb" \
			-rd target_netlist="$KLAYOUT_RUNDIR/${FBASENAME}_extracted.cir" \
			> "$KLAYOUT_LOG" 2>&1
	elif echo "$PDK" | grep -q -i -E "ihp-sg13g2|ihp-sg13cmos5l"; then
		# the ihp-sg13g2 and ihp-sg13cmos5l wrappers share the same CLI.
		# --disable_tap_extraction skips ntap1/ptap1 device extraction so taps are not required in the schematic (aligns with Magic+Netgen LVS).
		python3 "$PDKPATH/libs.tech/klayout/tech/lvs/run_lvs.py" \
			--layout="$CELL_LAY" \
			--netlist="$NETLIST_KLAYOUT" \
			--topcell="$TOPCELL" \
			--run_dir="$KLAYOUT_RUNDIR" \
			--run_mode=deep \
			--disable_tap_extraction \
			> "$KLAYOUT_LOG" 2>&1
	elif echo "$PDK" | grep -q -i "^ics55"; then
		# digital-only deck written for the image, MOS devices are compared without bulk (see the deck header)
		klayout -b -r "$PDKPATH/libs.tech/klayout/lvs/ics55.lvs" \
			-rd input="$CELL_LAY" \
			-rd topcell="$TOPCELL" \
			-rd schematic="$NETLIST_KLAYOUT" \
			-rd report="$KLAYOUT_RUNDIR/$FBASENAME.lvsdb" \
			-rd target_netlist="$KLAYOUT_RUNDIR/${FBASENAME}_extracted.cir" \
			-rd run_mode=deep \
			> "$KLAYOUT_LOG" 2>&1
	fi

	# no .lvsdb means the run itself failed (a comparison with violations still writes one). The reason is in the log.
	if ! find "$KLAYOUT_RUNDIR" -name '*.lvsdb' 2>/dev/null | grep -q .; then
		echo "[ERROR] KLayout LVS run failed (no result produced), see <$KLAYOUT_LOG>!"
		[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"
		exit $ERR_NO_RESULT
	fi
	JSON_REPORTS="$JSON_REPORTS
$(find "$KLAYOUT_RUNDIR" -name '*.lvsdb' | sort)"
	if [ -z "$JOINS" ] && [ "$WRAPPER" -eq 0 ]; then
		# the KLayout LVS decks print this exact line on a match (same string the IHP wrapper parses)
		grep -r -q "Congratulations! Netlists match." "$KLAYOUT_RUNDIR" || KLAYOUT_OK=0
	else
		# -J and -W: the deck fails the comparison on the port mismatches they accept, so the verdict comes from the report itself
		_lvsdbs=$(find "$KLAYOUT_RUNDIR" -name '*.lvsdb' | sort)
		set -f
		_ifs=$IFS
		IFS='
'
		for _lvsdb in $_lvsdbs; do
			klayout_xref_verdict "$_lvsdb" || KLAYOUT_OK=0
		done
		IFS=$_ifs
		set +f
	fi
fi

# the decompressed layout is no longer needed after extraction
[ -n "$GZ_TMP" ] && rm -f "$GZ_TMP"

# ============================================================================
# evaluate results
# ============================================================================

echo "---"

LVS_CLEAN=1

if [ "$RUN_MAGIC" -eq 1 ]; then
	if [ "$MAGIC_OK" -eq 1 ]; then
		echo "[INFO] Magic+Netgen LVS is OK, schematic/netlist and layout match!"
	else
		echo "[INFO] Magic+Netgen LVS errors found! Please check <$LVS_REPORT>!"
		[ "$MAGIC_PROPERR" -eq 1 ] && echo "[INFO] Netgen found property errors: device parameters (W, L, ...) differ between schematic/netlist and layout."
		LVS_CLEAN=0
	fi
fi

if [ "$RUN_KLAYOUT" -eq 1 ]; then
	if [ "$KLAYOUT_OK" -eq 1 ]; then
		echo "[INFO] KLayout LVS is OK, schematic/netlist and layout match!"
	else
		echo "[INFO] KLayout LVS errors found! Please check <$KLAYOUT_RUNDIR>!"
		LVS_CLEAN=0
	fi
fi

[ "$JSON" -eq 1 ] && json_result "$CELL_LAY_GIVEN"

echo "---"

if [ "$LVS_CLEAN" -eq 1 ]; then
	echo "CONGRATULATIONS! LVS is OK, schematic/netlist and layout match!"
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
	echo "LVS ERRORS FOUND! Please check the report(s) above!"
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
	exit $ERR_LVS_MISMATCH
fi
echo "[DONE] Bye!"
