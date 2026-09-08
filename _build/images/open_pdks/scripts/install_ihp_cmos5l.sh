#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
set -e
set -o pipefail
export SCRIPT_DIR=$TOOLS/osic-multitool
PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd /tmp || exit 1

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# Post-processing of the CMOS5L PDK. install_ihp.sh installs both IHP PDK
# trees from the single IHP-Open-PDK repository (IHP-Open-PDK#1124) and writes
# their COMMIT files, so this script only prepares the CMOS5L one. It has to
# run after install_ihp.sh: CMOS5L reaches into SG13G2 through relative
# symlinks (pycell code, xschem libraries, the SRAM Liberty files, the
# thick-oxide standard cells), and its Verilog-A sources for psp103, r3_cmc
# and mosvar are symlinks into SG13G2 as well.
PDK="ihp-sg13cmos5l"

if [ ! -d "$PDK_ROOT/$PDK" ]; then
    echo "[ERROR] IHP SG13CMOS5L PDK not found at $PDK_ROOT/$PDK."
    echo "[ERROR] Please run install_ihp.sh first, it installs both IHP PDKs."
    exit 1
fi
if [ ! -d "$PDK_ROOT/ihp-sg13g2" ]; then
    echo "[ERROR] IHP SG13G2 PDK not found at $PDK_ROOT/ihp-sg13g2."
    echo "[ERROR] CMOS5L symlinks into it, so both have to be installed."
    exit 1
fi

echo "[INFO] Preparing the IHP SG13CMOS5L PDK."

# Add custom bindkeys for Magic
echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"
echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"

# Fix KLayout netlist import templates (make m= optional, accept nf= for ng=).
# CMOS5L ships its own copy of ihp130_pcell_templates.py rather than a symlink
# into SG13G2, so install_ihp.sh's patch does not reach it and it has to be
# applied here too. Shared helper, same fix for both PDKs.
echo "[INFO] Fixing KLayout netlist import templates."
TEMPLATES_FILE="$PDK_ROOT/$PDK/libs.tech/klayout/python/import_netlist/ihp130_pcell_templates.py"
if [ -f "$TEMPLATES_FILE" ]; then
	python3 "$PDK_SCRIPT_DIR/fix_netlist_templates.py" "$TEMPLATES_FILE"
else
	echo "[WARN] KLayout netlist import templates not found at $TEMPLATES_FILE"
fi

# Anchor the KLayout GUI DRC/LVS run directory to the layout file, and add the
# %top_cell% placeholder. CMOS5L ships its own copies of the DRC and LVS menu
# macros and their options dialogs rather than symlinks into SG13G2, so
# install_ihp.sh's patch does not reach them. Shared helper, same fix for both
# PDKs, see install_ihp.sh for what it does and why.
echo "[INFO] Fixing the KLayout GUI DRC/LVS run directory."
python3 "$PDK_SCRIPT_DIR/fix_klayout_run_dir.py" "$PDK_ROOT/$PDK/libs.tech/klayout/tech/macros"

# Remove testing folders to save space
echo "[INFO] Removing unnecessary files to save space."
cd "$PDK_ROOT/$PDK"
find . -name "testing" -print0 | xargs -0 rm -rf

# Remove *.orig files created during PDK preparation
find "$PDK_ROOT/$PDK/libs.tech/xschem" -name "*.orig" -delete

# Rebuild the Verilog-A models for ngspice, the same way install_ihp.sh does
# for SG13G2: in-image and with --compile-model-generic, so the resulting OSDI
# runs on any host CPU. The PDK repo ships cap_cmomi and cap_cmomf prebuilt,
# but they come from whoever committed them (unknown OpenVAF version and target
# CPU), so they are not trustworthy for the image.
# The PDK's own openvaf-compile-va.sh builds every object CMOS5L needs -- its
# own cap_cmomi and cap_cmomf, plus psp103, psp103_nqs, r3_cmc and mosvar from
# the SG13G2 sources the symlinks in libs.tech/verilog-a point at. There are no
# OSDI symlinks into SG13G2 any more, so nothing here can rely on
# install_ihp.sh having produced them.
# NOTE: this is the ngspice copy in libs.tech/ngspice/osdi. The VACASK copies in
# libs.tech/vacask/osdi are built separately further down.
echo "[INFO] Compiling Verilog-A models."
export PATH="$TOOLS/openvaf/bin:$PATH"
VA_DIR="$PDK_ROOT/$PDK/libs.tech/verilog-a"
NGSPICE_OSDI_DIR="$PDK_ROOT/$PDK/libs.tech/ngspice/osdi"

# Drop the prebuilt objects first: openvaf-compile-va.sh does not set -e, so
# without this the check below would happily pass on the stale shipped files.
# Only real files, so a symlink into SG13G2 -- should the PDK ever go back to
# borrowing an object -- is left for the check below to judge.
find "$NGSPICE_OSDI_DIR" -maxdepth 1 -type f -name '*.osdi' -delete
cd "$VA_DIR" || exit 1
chmod +x openvaf-compile-va.sh
./openvaf-compile-va.sh --compile-model-generic

# Verify every OSDI object the PDK's own .spiceinit loads is there. Since the
# compile script and .spiceinit are both PDK-side, this is the completeness
# gate: it follows the PDK when it gains a device instead of naming the models
# here (cap_cmomf arrived that way in 2026-08). -f follows symlinks, so a
# dangling one is caught too. A missing object makes every ngspice run using
# that device fail at load time, which is worth failing the build for rather
# than shipping.
SPICEINIT="$PDK_ROOT/$PDK/libs.tech/ngspice/.spiceinit"
OSDI_MISSING=0
if [ -f "$SPICEINIT" ]; then
	for osdi_name in $(grep -o '[A-Za-z0-9_]*\.osdi' "$SPICEINIT" | sort -u); do
		if [ ! -f "$NGSPICE_OSDI_DIR/$osdi_name" ]; then
			echo "[ERROR] $osdi_name is loaded by .spiceinit but missing in $NGSPICE_OSDI_DIR!"
			OSDI_MISSING=1
		fi
	done
else
	echo "[ERROR] $SPICEINIT not found, cannot verify the OSDI objects ngspice loads."
	OSDI_MISSING=1
fi
if [ "$OSDI_MISSING" -ne 0 ]; then
	exit 1
fi

# Perform required preparation of IHP CMOS5L PDK for use with VACASK.
# Upstream's sg13cmos5ltovc.py does all of it (requested as
# https://codeberg.org/arpadbuermen/VACASK/issues/94): it converts the ngspice
# models, compiles cap_cmomi.va to OSDI, symlinks in the SG13G2 OSDI objects,
# writes .vacaskrc.toml and patches the xschem symbols and xschemrc.
# Needs VACASK >= b9ca96e, which keeps the conversion of the models CMOS5L
# symlinks from SG13G2 inside the CMOS5L tree and makes cap_cmomi's feed
# default a literal, so it stays overridable (regression test 29).
#
# The converter names the devices it handles in two hardcoded lists, while the
# PDK is installed unpinned and grows devices between VACASK releases, so the
# lists are completed from the PDK before it runs (see the helper for what that
# costs when it is not done -- it broke the whole CMOS5L VACASK capacitor path
# when cap_cmomf arrived).
echo "[INFO] Preparing IHP CMOS5L PDK for VACASK."
cd /tmp || exit 1
rm -rf "${VACASK_NAME}"

if [ -z "${VACASK_REPO_COMMIT:-}" ]; then
	# No specific ref -> shallow clone the default branch for speed
	git clone --filter=blob:none --depth 1 "${VACASK_REPO_URL}" "${VACASK_NAME}"
	cd "${VACASK_NAME}" || exit 1
else
	# When a specific ref (branch, tag, or commit) is given try a shallow fetch of that ref.
	# Use --no-checkout so we can fetch a single ref shallowly without downloading history.
	git clone --filter=blob:none --no-checkout "${VACASK_REPO_URL}" "${VACASK_NAME}"
	cd "${VACASK_NAME}" || exit 1

	# Try to fetch the exact ref shallowly. This usually works for branches and tags and
	# for commit SHAs on servers that allow fetching by SHA with depth.
	if git fetch --depth 1 origin "${VACASK_REPO_COMMIT}" >/dev/null 2>&1; then
		git checkout FETCH_HEAD
	else
		# Fallback: fetch all refs and tags, then checkout the requested ref (slower but reliable)
		git fetch --all --tags --prune
		git checkout "${VACASK_REPO_COMMIT}"
	fi
fi
cd /tmp || exit 1

# Complete the converter's device lists from the PDK before running it.
echo "[INFO] Checking the VACASK converter against the installed PDK."
python3 "$PDK_SCRIPT_DIR/fix_cmos5l_vacask_converter.py" \
	"/tmp/${VACASK_NAME}/python/sg13cmos5ltovc.py" "$PDK_ROOT/$PDK"

OPENVAF_DIR=${TOOLS}/openvaf/bin PYTHONPATH=/tmp/${VACASK_NAME}/python \
    PDK_ROOT="$PDK_ROOT" PDK="$PDK" \
    python3 -m sg13cmos5ltovc --openvaf-options --target_cpu generic

# Every file the converted models include has to exist, or a deck pulling in
# that file dies on the include even when it uses none of the devices behind it
# -- which is exactly how the missing cap_cmomf conversion broke the whole
# CMOS5L capacitor path via cornerCAP.lib. Checked here rather than trusted,
# because the unpinned PDK and the pinned converter drift independently.
# ng2vclib writes includes as 'include "<file>"[ section=<sec>]' (see
# ng2vclib/m_output.py), with paths relative to the including file.
echo "[INFO] Verifying the converted VACASK model includes resolve."
VACASK_MODELS="$PDK_ROOT/$PDK/libs.tech/vacask/models"
INCLUDE_MISSING=0
for model in "$VACASK_MODELS"/*.lib; do
	[ -f "$model" ] || continue
	for inc in $(sed -n 's/^[[:space:]]*include[[:space:]]*"\([^"]*\)".*/\1/p' "$model" | sort -u); do
		if [ ! -f "$(dirname "$model")/$inc" ]; then
			echo "[ERROR] $(basename "$model") includes $inc, which was not converted!"
			INCLUDE_MISSING=1
		fi
	done
done
if [ "$INCLUDE_MISSING" -ne 0 ]; then
	echo "[ERROR] The VACASK model conversion is incomplete."
	exit 1
fi

# ---------------------------------------------------------------------------
# Add the diode and PNP corners to the "Add VACASK models symbol" menu entry.
#
# The corner list upstream ships covers MOSlv, MOShv, RES and CAP only, so a
# design using a diode or the pnpMPA gets no corner section for it and has to
# add the include by hand. CMOS5L converts both corner files, so list them.
# Upstream omits cornerDIO for SG13G2 as well, i.e. this is a local addition
# and not a fix -- keep it as a separate, clearly bounded edit.
# ---------------------------------------------------------------------------
echo "[INFO] Adding the diode and PNP corners to the xschem VACASK menu."
python3 - "$PDK_ROOT" "$PDK" << 'PYEOF'
import os
import sys

pdkroot, pdk = sys.argv[1], sys.argv[2]
path = os.path.join(pdkroot, pdk, "libs.tech", "xschem", "xschem-vacask")

with open(path) as f:
    tcl = f.read()

anchor = 'include \\"cornerCAP.lib\\" section=cap_typ\n'
added = ('include \\"cornerDIO.lib\\" section=dio_tt\n'
         'include \\"cornerPNP.lib\\" section=typ\n')

if 'cornerDIO.lib' in tcl and 'cornerPNP.lib' in tcl:
    print("[INFO] Diode and PNP corners already listed, nothing to do.")
elif anchor not in tcl:
    print("[WARN] cornerCAP.lib entry not found in %s, corner list left as is "
          "(upstream changed the menu?)" % path)
else:
    with open(path, "w") as f:
        f.write(tcl.replace(anchor, anchor + added, 1))
    print("[INFO] Added cornerDIO.lib and cornerPNP.lib to the corner list.")
PYEOF

# The xschem "Create FET .save file" menu entry and the matching launcher on the
# xschem start page run "mkdir -p $netlist_dir" -- a shell command -- from Tcl.
# Clicking either aborts with `invalid command name "mkdir"` and no .save file is
# written. Tcl's own `file mkdir` is the exact equivalent: it creates parent
# directories and does not complain about an existing one.
# SG13G2 fixed this in the PDK (its libs.tech/xschem/xschem-menu and
# start_page.sch already read `file mkdir`), CMOS5L still carries the shell
# version: the fix was made in the standalone iic-jku/ihp-sg13cmos5l fork and
# did not come along when the PDK moved into IHP-Open-PDK. Drop this once
# iic-jku/IHP-Open-PDK#61 has landed and the image is rebuilt.
echo "[INFO] Fixing the xschem 'Create FET .save file' entries."
for xschem_file in xschem-menu start_page.sch; do
	XSCHEM_FILE="$PDK_ROOT/$PDK/libs.tech/xschem/$xschem_file"
	if [ ! -f "$XSCHEM_FILE" ]; then
		echo "[WARN] xschem file not found at $XSCHEM_FILE"
	elif grep -q '^[[:space:]]*mkdir -p \$netlist_dir[[:space:]]*$' "$XSCHEM_FILE"; then
		sed -i 's/^\([[:space:]]*\)mkdir -p \$netlist_dir[[:space:]]*$/\1file mkdir $netlist_dir/' "$XSCHEM_FILE"
		echo "[INFO] Replaced 'mkdir -p' by 'file mkdir' in $XSCHEM_FILE"
	else
		echo "[WARN] 'mkdir -p \$netlist_dir' not found in $XSCHEM_FILE (already fixed upstream?)"
	fi
done

# Drop the backups the converter leaves behind: xschemrc.orig from its own
# xschemrc patcher and *.sym.orig from xschem2vc's symbol patcher.
find "$PDK_ROOT/$PDK/libs.tech/xschem" -name "*.orig" -delete
if [ -d "$PDK_ROOT/$PDK/libs.ref/sg13cmos5l_stdcell/sym" ]; then
	find "$PDK_ROOT/$PDK/libs.ref/sg13cmos5l_stdcell/sym" -name "*.orig" -delete
fi

rm -rf "/tmp/${VACASK_NAME}"

# gzip Liberty (.lib) files. The SRAM and thick-oxide standard-cell Liberty
# files are symlinks into the SG13G2 PDK and are already compressed by
# install_ihp.sh; gzip_liberty.sh leaves those links alone and only rewrites
# the references to them.
bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/$PDK"

# CMOS5L is largely symlinks into SG13G2, so a rename on the SG13G2 side silently
# leaves a broken link behind. Report them instead of failing the build, 
# since a dangling link is a PDK-side fix and not every one of them blocks the tools.
echo "[INFO] Checking for broken symlinks into SG13G2."
BROKEN_LINKS=$(find "$PDK_ROOT/$PDK" -xtype l || true)
if [ -n "$BROKEN_LINKS" ]; then
	echo "[WARN] Broken symlinks found in $PDK:"
	echo "$BROKEN_LINKS" | sed 's/^/[WARN]   /'
else
	echo "[INFO] No broken symlinks found."
fi

echo "[INFO] IHP SG13CMOS5L PDK installation complete."
