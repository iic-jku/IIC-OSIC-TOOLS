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
# Usage: sak-pex.sh [-d] [-k] [-m <mode>] [-s <mode>] [-n <subcktname>] [-w <workdir>]
#                   [-c <cthresh>] [-t <threshold>] [-r <minres>] [-y <mindelay>]
#                   [-S <schematic>] [-R <reduction>] [-g <net>] <cellname>
#        -k  Use the KPEX 2.5D engine instead of Magic
#        -m  Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)
#        -s  Subcircuit definition (1 = include [default], 0 = no subcircuit)
#        -n  Name of PEX subcircuit (default: <cellname>)
#        -w  Use <workdir> to store result files (default: current dir)
#        -c  Magic only: capacitance threshold in fF, smaller capacitors are left out of the netlist (default: 0.01 = 10 aF, Magic writes capacitors below 0.001 as 0)
#        -t  Magic, full-RC only: extresist threshold in mOhm (default: 10000 = 10 Ohm)
#        -r  Magic, full-RC only: extresist minres in mOhm (default: 1000 = 1 Ohm)
#        -y  Magic, full-RC only: extresist mindelay in ps (default: 1, 0 = gate by resistance)
#        -S  kpex only: schematic netlist (SPICE or CDL) that kpex checks its devices and ports against and takes the port order from (default: none)
#        -R  kpex, full-RC only: netlist reduction (none, floating, ticer [default])
#        -g  kpex only: net the substrate port is tied to (default: VSS, an empty net keeps the substrate port, a given net that is no port stops the run where the default only warns)
#        -d  Enable debug information
#
#        <cellname> may be a cell name or a layout file (.mag, .mag.gz, .gds, .gds.gz), kpex reads GDS only
#        NOTE: for a GDS input the top cell must be named like the file, otherwise the script aborts
#
# Example: sak-pex.sh -m 3 -t 5000 -r 500 -y 2 -n mycell_pex -w ./results mycell.gds
#          sak-pex.sh -k -m 3 -S mycell.cdl -n mycell_pex -w ./results mycell.gds
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
	echo "PEX script using Magic or the kpex 2.5D engine (ICD@JKU)"
	echo
	echo "Usage: $0 [-d] [-k] [-m <mode>] [-s <mode>] [-n <subcktname>] [-w <workdir>]"
	echo "       [-c <cthresh>] [-t <threshold>] [-r <minres>] [-y <mindelay>]"
	echo "       [-S <schematic>] [-R <reduction>] [-g <net>] <cellname>"
	echo
	echo "       -k Use the KPEX 2.5D engine instead of Magic"
	echo "       -m Select PEX mode (1 = C-decoupled, 2 = C-coupled [default], 3 = full-RC)"
	echo "       -s Subcircuit definition in PEX netlist (1 = include subcircuit definition [default], 0 = no subcircuit)"
	echo "       -n Name of PEX subcircuit (default is <cellname>)"
	echo "       -w Use <workdir> to store result files (default current dir)"
	echo "       -c Magic only: capacitance threshold in fF, smaller capacitors are left out of the netlist (default 0.01 = 10 aF, Magic writes capacitors below 0.001 as 0)"
	echo "       -t Magic, full-RC only: extresist threshold in mOhm (default 10000 = 10 Ohm)"
	echo "       -r Magic, full-RC only: extresist minres in mOhm (default 1000 = 1 Ohm)"
	echo "       -y Magic, full-RC only: extresist mindelay in ps (default 1, 0 = gate by resistance instead of delay)"
	echo "       -S kpex only: schematic netlist (SPICE or CDL) that kpex checks its devices and ports against and takes the port order from (default none)"
	echo "       -R kpex, full-RC only: netlist reduction (none, floating, ticer [default])"
	echo "       -g kpex only: net the substrate port is tied to (default VSS, an empty net keeps the substrate port, a given net that is no port stops the run where the default only warns)"
	echo "       -d Enable debug information"
	echo
	echo "       <cellname> may be a cell name or a layout file (.mag, .mag.gz, .gds, .gds.gz), kpex reads GDS only"
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

# fF: capacitors below this are left out of the netlist (Magic, all modes)
EXT_CTHRESH=0.01

# full-RC (extresist) defaults, matching Magic's own defaults
EXT_THRESHOLD=10000	# mOhm: coarse end-to-end resistance gating extraction
EXT_MINRES=1000		# mOhm: resistors below this are merged (simplification)
EXT_MINDELAY=1		# ps: delay-based output gating (0 = gate by resistance)

# kpex engine defaults
ENGINE=magic
KPEX_SCHEMATIC=""
KPEX_REDUCE=ticer
KPEX_SUB_NET=VSS
KPEX_SUB_NET_SET=0
# flags given for the other engine, rejected below
MAGIC_ONLY_FLAGS=""
KPEX_ONLY_FLAGS=""

# check flags
# -----------

while getopts "m:s:n:w:c:t:r:y:dkS:R:g:" flag; do
	case $flag in
		k)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -k is set."
			ENGINE=kpex
			;;
		S)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -S is set to <$OPTARG>."
			KPEX_SCHEMATIC=${OPTARG}
			KPEX_ONLY_FLAGS="$KPEX_ONLY_FLAGS -S"
			;;
		R)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -R is set to <$OPTARG>."
			KPEX_REDUCE=${OPTARG}
			KPEX_ONLY_FLAGS="$KPEX_ONLY_FLAGS -R"
			;;
		g)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -g is set to <$OPTARG>."
			KPEX_SUB_NET=${OPTARG}
			KPEX_SUB_NET_SET=1
			KPEX_ONLY_FLAGS="$KPEX_ONLY_FLAGS -g"
			;;
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
		c)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -c is set to <$OPTARG>."
			EXT_CTHRESH=${OPTARG}
			MAGIC_ONLY_FLAGS="$MAGIC_ONLY_FLAGS -c"
			;;
		t)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -t is set to <$OPTARG>."
			EXT_THRESHOLD=${OPTARG}
			MAGIC_ONLY_FLAGS="$MAGIC_ONLY_FLAGS -t"
			;;
		r)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -r is set to <$OPTARG>."
			EXT_MINRES=${OPTARG}
			MAGIC_ONLY_FLAGS="$MAGIC_ONLY_FLAGS -r"
			;;
		y)
			[ $DEBUG -eq 1 ] && echo "[INFO] flag -y is set to <$OPTARG>."
			EXT_MINDELAY=${OPTARG}
			MAGIC_ONLY_FLAGS="$MAGIC_ONLY_FLAGS -y"
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

# check that the capacitance threshold is a non-negative decimal number
# ---------------------------------------------------------------------

# Magic takes any string here without an error, and a word drops every capacitor
case "$EXT_CTHRESH" in
	''|.|*[!0-9.]*|*.*.*)
		echo "[ERROR] Capacitance threshold must be a non-negative decimal number in fF (e.g. 0.01)!"
		exit $ERR_WRONG_MODE ;;
esac

# check that the flags fit the engine and the kpex reduction is valid
# --------------------------------------------------------------------

if [ "$ENGINE" = "kpex" ] && [ -n "$MAGIC_ONLY_FLAGS" ]; then
	echo "[ERROR] Flag(s)$MAGIC_ONLY_FLAGS apply to the Magic engine only, not to kpex (-k)!"
	exit $ERR_WRONG_MODE
fi
if [ "$ENGINE" = "magic" ] && [ -n "$KPEX_ONLY_FLAGS" ]; then
	echo "[ERROR] Flag(s)$KPEX_ONLY_FLAGS apply to the kpex engine (-k) only!"
	exit $ERR_WRONG_MODE
fi
case "$KPEX_REDUCE" in
	none|floating|ticer) ;;
	*)
		echo "[ERROR] Unknown kpex reduction <$KPEX_REDUCE> (expected none, floating or ticer)!"
		exit $ERR_WRONG_MODE ;;
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

# kpex knows these four PDKs by name. Its PEX-LVS puts the substrate on one global net, a port of the netlist unless a tap and a label name it otherwise (e.g. VSS).
if [ "$ENGINE" = "kpex" ]; then
	case "$PDK" in
		ihp-sg13g2|ihp-sg13cmos5l)	KPEX_SUB="sub!" ;;
		sky130A)			KPEX_SUB="sky130_gnd" ;;
		gf180mcuD)			KPEX_SUB="SUB" ;;
		*)
			echo "[ERROR] The PDK $PDK is not supported by kpex (ihp-sg13g2, ihp-sg13cmos5l, sky130A, gf180mcuD)!"
			exit $ERR_PDK_NOT_SUPPORTED ;;
	esac
	if [ "$KPEX_SUB_NET" = "$KPEX_SUB" ]; then
		echo "[ERROR] -g names the substrate port <$KPEX_SUB> itself, give a port net, or an empty net to keep the port!"
		exit $ERR_WRONG_MODE
	fi
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
		case "$ENGINE:$_lay" in
			kpex:*.mag|kpex:*.mag.gz) continue ;;
		esac
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

if [ "$ENGINE" = "kpex" ]; then
	case "$CELL_LAY" in
		*.mag|*.mag.gz)
			echo "[ERROR] kpex reads GDS layouts only (.gds, .gds.gz, .klay.gds), not <$CELL_LAY>!"
			exit $ERR_UNKNOWN_FILE ;;
	esac
	if [ -n "$KPEX_SCHEMATIC" ] && [ ! -f "$KPEX_SCHEMATIC" ]; then
		echo "[ERROR] Schematic netlist <$KPEX_SCHEMATIC> not found!"
		exit $ERR_FILE_NOT_FOUND
	fi
fi

[ $DEBUG -eq 1 ] && echo "[INFO] Using layout file <$CELL_LAY>."

# check that the required tools are available
# -------------------------------------------

if [ "$ENGINE" = "kpex" ]; then
	if [ ! -x "$(command -v kpex)" ]; then
		echo "[ERROR] kpex could not be found!"
		exit $ERR_CMD_NOT_FOUND
	fi
	if [ ! -x "$(command -v python3)" ]; then
		echo "[ERROR] python3 could not be found!"
		exit $ERR_CMD_NOT_FOUND
	fi
elif [ ! -x "$(command -v magic)" ]; then
	echo "[ERROR] Magic could not be found!"
	exit $ERR_CMD_NOT_FOUND
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

# decompress gzipped layout views, Magic cannot read them directly (kpex can)
# --------------------------------------------------------------------------

# a .mag.gz must keep its cell name (<cell>.mag) so Magic loads it as $CELL_NAME. A private temp dir keeps that name without clobbering anything.
TMP_MAG_DIR=""
# a .gds.gz is decompressed into the result dir under a cell-specific name so runs do not collide. Both temp copies are removed during cleanup.
TMP_GDS=""
[ "$ENGINE" = "magic" ] && case "$CELL_LAY" in
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

case "$EXT_MODE" in
	1)	EXT_MODE_TEXT="C-decoupled" ;;
	2)	EXT_MODE_TEXT="C-coupled" ;;
	3)	EXT_MODE_TEXT="full-RC" ;;
esac

# extract the PEX netlist with the kpex 2.5D engine
# -------------------------------------------------

if [ "$ENGINE" = "kpex" ]; then
	case "$EXT_MODE" in
		1)	KPEX_MODE=C ;;
		2)	KPEX_MODE=CC ;;
		3)	KPEX_MODE=RC ;;
	esac
	# kpex writes its run directory (LVS, reports, LVSDB cache) here, it is removed after a successful run
	KPEX_DIR="$RESDIR/.pextmp_kpex_${CELL_NAME}_$$"
	KPEX_EXIT_FILE="$KPEX_DIR.exit"
	# a netlist of an earlier run must not be mistaken for the output of a failed one
	rm -f "$NETLIST_PEX" "$NETLIST_PEX.tmp"

	# --blackbox y keeps MIM and MOM capacitors as devices with their SPICE models, without it kpex replaces them by their extracted plates
	set -- kpex extract --log-level info --pdk "$PDK" --cell "$CELL_NAME" --gds "$CELL_LAY" \
		--2.5D --mode "$KPEX_MODE" --blackbox y --out-dir "$KPEX_DIR" --out-netlist "$NETLIST_PEX.tmp"
	[ "$EXT_MODE" -eq 3 ] && set -- "$@" --reduce "$KPEX_REDUCE"
	[ -n "$KPEX_SCHEMATIC" ] && set -- "$@" --schematic "$KPEX_SCHEMATIC"
	[ $DEBUG -eq 1 ] && echo "[INFO] Running <$*>."

	if [ $DEBUG -eq 0 ]; then
		"$@" > "$PEX_LOG" 2>&1
		KPEX_EXIT=$?
	else
		# sh has no PIPESTATUS, so the exit code of kpex goes through a file
		{ "$@"; echo $? > "$KPEX_EXIT_FILE"; } 2>&1 | tee "$PEX_LOG"
		KPEX_EXIT=$(cat "$KPEX_EXIT_FILE" 2>/dev/null)
		rm -f "$KPEX_EXIT_FILE"
	fi

	# kpex exits non-zero also for a failed --check (in full-RC, a device or port mismatch against -S), after it wrote the netlist
	if [ "$KPEX_EXIT" != "0" ]; then
		grep -q "Could not find cell" "$PEX_LOG" && echo "[ERROR] The GDS has no cell <$CELL_NAME>, rename the layout file/cell so they match, then re-run."
		echo "[ERROR] kpex stopped with exit code <$KPEX_EXIT>, see <$PEX_LOG>!"
		echo "[ERROR] Its run directory <$KPEX_DIR> is kept for inspection."
		rm -f "$NETLIST_PEX.tmp"
		exit $ERR_GENERAL
	fi
	if [ ! -f "$NETLIST_PEX.tmp" ]; then
		echo "[ERROR] No PEX netlist produced, see <$PEX_LOG>!"
		echo "[ERROR] Its run directory <$KPEX_DIR> is kept for inspection."
		exit $ERR_GENERAL
	fi
	# outside full-RC a failed --check is a warning, which would otherwise stay in the log
	grep -q "The extracted netlist is inconsistent" "$PEX_LOG" && \
		echo "[WARNING] kpex found the extracted netlist inconsistent with its LVS netlist or the schematic, see <$PEX_LOG>."

	HEADER="* PEX produced on $(date) using $0 with m=$EXT_MODE and s=$SUBCIRCUIT (kpex 2.5D: --mode $KPEX_MODE"
	[ "$EXT_MODE" -eq 3 ] && HEADER="$HEADER --reduce $KPEX_REDUCE"
	HEADER="$HEADER --blackbox y"

	# rename the subcircuit (-n), drop its wrapper (-s 0) and tie the substrate port to a port net (-g)
	if ! python3 -I - "$NETLIST_PEX.tmp" "$NETLIST_PEX" "$HEADER" "$CELL_NAME" "$CELL_NAME_PEX" "$SUBCIRCUIT" \
		"$KPEX_SUB" "$KPEX_SUB_NET" "$KPEX_SUB_NET_SET" << 'EOF'
import re
import sys

src, dst, header, cell, name, subckt, sub, net, net_set = sys.argv[1:10]
lines = open(src, encoding="utf-8").read().splitlines()


def rename(line):
    """Rename the subcircuit in a .SUBCKT or .ENDS line, keeping the rest of the line as it is."""
    return re.sub(r"^(\s*\S+\s+)" + re.escape(cell) + r"(?=\s|$)", lambda m: m.group(1) + name, line)


# the ports of the cell, kpex wraps a long port list over "+" lines
ports = None
for i, line in enumerate(lines):
    tokens = line.split()
    if len(tokens) > 1 and tokens[0].lower() == ".subckt" and tokens[1] == cell:
        ports = tokens[2:]
        for cont in lines[i + 1:]:
            if not cont.startswith("+"):
                break
            ports += cont[1:].split()
        break
if ports is None:
    sys.exit(f"[ERROR] The kpex netlist has no subcircuit <{cell}>!")

tie = sub in ports and net != ""
if sub in ports and net == "":
    print(f"[INFO] The substrate port <{sub}> is kept (-g with an empty net).")
if tie and net not in ports:
    if net_set == "1":
        sys.exit(f"[ERROR] Net <{net}> is not a port of <{cell}>, so the substrate port <{sub}> cannot be tied to it (-g)!")
    print(f"[WARNING] Net <{net}> is not a port of <{cell}>, so the substrate port <{sub}> is kept (select a net with -g).")
    tie = False

out, moved, dropped, in_cell = [], 0, 0, False
i = 0
while i < len(lines):
    first = i
    line = lines[i]
    i += 1
    tokens = line.split()
    if tokens and tokens[0].lower() == ".subckt":
        while i < len(lines) and lines[i].startswith("+"):
            tokens += lines[i][1:].split()
            i += 1
        in_cell = len(tokens) > 1 and tokens[1] == cell
        if not in_cell:
            out += lines[first:i]
        elif subckt == "0":
            pass
        elif tie:
            out.append(" ".join([tokens[0], name] + [t for t in tokens[2:] if t != sub]))
        else:
            out += [rename(lines[first])] + lines[first + 1:i]
        continue
    if not in_cell:
        out.append(line)
        continue
    if tokens and tokens[0].lower() == ".ends":
        in_cell = False
        if subckt != "0":
            out.append(rename(line))
        continue
    if not tie or not tokens or line.startswith("*") or sub not in tokens[1:]:
        out.append(line)
        continue
    tokens = [tokens[0]] + [net if t == sub else t for t in tokens[1:]]
    # an R or C with both ends on the tied net does nothing
    if tokens[0][0].lower() in "rc" and tokens[1] == tokens[2]:
        dropped += 1
        continue
    moved += 1
    out.append(" ".join(tokens))

if tie:
    header += f", substrate port {sub} tied to {net}"
    print(f"[INFO] Tied the substrate port <{sub}> to <{net}>: {moved} element lines moved, "
          f"{dropped} elements between <{sub}> and <{net}> dropped.")
with open(dst, "w", encoding="utf-8") as f:
    f.write(header + ")\n" + "\n".join(out) + "\n")
EOF
	then
		echo "[ERROR] Post-processing failed, the netlist of kpex stays in <$NETLIST_PEX.tmp> and its run directory in <$KPEX_DIR>."
		rm -f "$NETLIST_PEX"
		exit $ERR_GENERAL
	fi

	rm -f "$NETLIST_PEX.tmp"
	rm -rf "$KPEX_DIR"
	echo "[INFO] PEX ($EXT_MODE_TEXT, kpex 2.5D) done, the extracted SPICE netlist is <$NETLIST_PEX>."
	echo "[DONE] Bye!"
	exit 0
fi

# generate the extract script for Magic
# -------------------------------------

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
	echo "ext2spice cthresh $EXT_CTHRESH"
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
HEADER="* PEX produced on $DATE using $0 with m=$EXT_MODE and s=$SUBCIRCUIT (cthresh=$EXT_CTHRESH fF"
[ "$EXT_MODE" -eq 3 ] && HEADER="$HEADER, extresist threshold=$EXT_THRESHOLD mOhm, minres=$EXT_MINRES mOhm, mindelay=$EXT_MINDELAY ps"
HEADER="$HEADER)"
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
