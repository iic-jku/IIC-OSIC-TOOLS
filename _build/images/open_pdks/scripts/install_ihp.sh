#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
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

# Install IHP-SG13G2
PDK="ihp-sg13g2"
IHP_REPO_URL="https://github.com/iic-jku/IHP-Open-PDK.git"

echo "[INFO] Installing IHP SG13G2 PDK."
git clone "$IHP_REPO_URL" ihp
cd ihp || exit 1
# For now uses branch "dev" to get the latest releases
git checkout dev
git submodule update --init --recursive

# Now move to the proper location
if [ -d "$PDK" ]; then
	mv "$PDK" "$PDK_ROOT/$PDK"
else
	echo "[ERROR] PDK directory '$PDK' not found after clone!"
	exit 1
fi

# Copy the repo-level `versions.txt` next to the PDK (at $PDK_ROOT) so the KLayout DRC/LVS version check can find it.
# This is mandatory since commit: https://github.com/IHP-GmbH/IHP-Open-PDK/commit/d54e4a48a3d34c555a038b64a0869cd295134376
if [ -f "versions.txt" ]; then
	cp "versions.txt" "$PDK_ROOT/versions.txt"
else
	echo "[ERROR] versions.txt not found in PDK repo. KLayout DRC/LVS version check may fail."
	exit 1
fi

# Store git hash of installed PDK version for reference
PDK_COMMIT=$(git rev-parse HEAD)
echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# Cleanup cloned repo to save space
cd /tmp || exit 1
rm -rf ihp

# Compile the additional Verilog-A models
echo "[INFO] Compiling Verilog-A models."
cd "$PDK_ROOT/$PDK/libs.tech/verilog-a" || exit 1
# ngspice
export PATH="$TOOLS/openvaf/bin:$PATH"
chmod +x openvaf-compile-va.sh
./openvaf-compile-va.sh --compile-model-generic
# Xyce
export PATH="$TOOLS/xyce/bin:$PATH"
chmod +x adms-compile-va.sh
./adms-compile-va.sh
if [ ! -f ../xyce/plugins/Xyce_Plugin_PSP103_VA.so ] || [ ! -f ../xyce/plugins/Xyce_Plugin_r3_cmc.so ]; then
    echo "[ERROR] ADMS model compilation for Xyce failed!"
    exit 1
fi

# Add custom bindkeys for Magic
echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"
echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"

# Fix KLayout netlist import templates: make m= optional for all devices
# (xschem omits m=1 when multiplicity equals the default value of 1)
# Also accept nf= as alternative to ng= for MOSFET finger count.
echo "[INFO] Fixing KLayout netlist import templates."
TEMPLATES_FILE="$PDK_ROOT/$PDK/libs.tech/klayout/python/import_netlist/ihp130_pcell_templates.py"
if [ -f "$TEMPLATES_FILE" ]; then
    python3 - "$TEMPLATES_FILE" << 'PYEOF'
import sys
fname = sys.argv[1]
with open(fname, 'r') as f:
    content = f.read()
# 1. Make m= optional in all regex patterns that currently require it.
#    Use a placeholder to protect patterns that are already optional.
old = r'(?=.*m=(?P<m>\d+))'
new = r'(?:(?=.*m=(?P<m>\d+))|)'
placeholder = '___OPTIONAL_M___'
content = content.replace(new, placeholder)
content = content.replace(old, new)
content = content.replace(placeholder, new)
# 2. Accept both ng= and nf= for MOSFET finger count
#    (xschem may generate nf= in some symbol versions instead of ng=)
content = content.replace(
    r'(?=.*ng=(?P<ng>\d+))',
    r'(?=.*(?:ng|nf)=(?P<ng>\d+))'
)
with open(fname, 'w') as f:
    f.write(content)
print(f"[INFO] Fixed KLayout netlist import templates in {fname}")
PYEOF
else
    echo "[WARN] KLayout netlist import templates not found at $TEMPLATES_FILE"
fi

# The IHP PDK renamed the IO netlist to libs.ref/sg13g2_io/spice/sg13g2_io.spice,
# but several consumers still expect the old name sg13g2_io.spi:
#   - libs.tech/librelane/config.tcl (PAD_SPICE_MODELS)
#   - libs.tech/xschem/sg13g2_tests/sg13g2_IOPad_tb.sch
#   - sg13g2tovc.py (VACASK PDK preparation below)
# Provide the expected name via a symlink until the PDK is consistent again.
IO_SPICE_DIR="$PDK_ROOT/$PDK/libs.ref/sg13g2_io/spice"
if [ ! -e "$IO_SPICE_DIR/sg13g2_io.spi" ] && [ -e "$IO_SPICE_DIR/sg13g2_io.spice" ]; then
	echo "[INFO] Adding sg13g2_io.spi -> sg13g2_io.spice compatibility symlink."
	ln -s sg13g2_io.spice "$IO_SPICE_DIR/sg13g2_io.spi"
fi

# The moscap_n/moscap_p callback entry in the KLayout PCell library is missing
# the "usePcellParameterAsArgument" key that cni/dlo.py indexes unconditionally
# in PCellDeclaration.coerce_parameters. The resulting KeyError is swallowed by
# KLayout, produce() never runs and both PCells come out empty. CbMoscap_wl is
# declared as `proc CbMoscap_wl {param}`, so the value has to be "true".
# Remove this once https://github.com/IHP-GmbH/IHP-Open-PDK/issues/1083 is fixed.
echo "[INFO] Fixing the moscap PCell callback definition."
CALLBACKS_FILE="$PDK_ROOT/$PDK/libs.tech/klayout/python/sg13g2_pycell_lib/callbacks/callbacks.json"
if [ -f "$CALLBACKS_FILE" ]; then
    # Patched textually, not via a JSON round-trip: the file uses repeated "_"
    # keys to carry its license header, and those collapse when re-serialized.
    python3 - "$CALLBACKS_FILE" << 'PYEOF'
import re
import sys

fname = sys.argv[1]
with open(fname, 'r') as f:
    content = f.read()

# Match the pcellParameters line of the CbMoscap_wl callback, unless the key is
# already there (upstream fix landed), and append it with the same indentation.
pattern = re.compile(
    r'("callback":\s*"CbMoscap_wl",\s*\n)'
    r'(\s*)("pcellParameters":\s*\[[^\]]*\])'
    r'(?!\s*,\s*\n\s*"usePcellParameterAsArgument")'
)
content, count = pattern.subn(
    lambda m: '%s%s%s,\n%s"usePcellParameterAsArgument": "true"'
              % (m.group(1), m.group(2), m.group(3), m.group(2)),
    content
)

if count:
    with open(fname, 'w') as f:
        f.write(content)
    print("[INFO] Added usePcellParameterAsArgument to the moscap callback in %s" % fname)
else:
    print("[WARN] moscap callback not patched in %s (already fixed upstream?)" % fname)
PYEOF
else
    echo "[WARN] KLayout PCell callback definition not found at $CALLBACKS_FILE"
fi

# KLayout 0.30.10 no longer merges the first input of a two-layer DRC check.
# The NBL rules pass the net-annotated nBuLay region unmerged, so edges that are
# interior to the nBuLay area become visible to the check and get measured
# against the second layer, which reports separations that do not exist. A
# DRC-clean sg13_dnwell_inv (from iic-jku/open-pdks-regression-tests) fails with
# 2x NBL.e and 1x NBL.f under 0.30.10 and is clean again with the merge back.
# All three nbl_nets checks are the same construct; NBL.d is patched along with
# the two that are known to misfire, since it is exposed in exactly the same way.
# Remove this once https://github.com/KLayout/klayout/issues/2416 is resolved.
echo "[INFO] Fixing the nBuLay DRC rules for KLayout >= 0.30.10."
NBULAY_DRC="$PDK_ROOT/$PDK/libs.tech/klayout/tech/drc/rule_decks/feol/5_3_nbulay.drc"
if [ -f "$NBULAY_DRC" ]; then
    python3 - "$NBULAY_DRC" << 'PYEOF'
import sys

fname = sys.argv[1]
with open(fname, 'r') as f:
    content = f.read()

# Naturally idempotent: the patched call no longer contains the searched text.
count = content.count('nbl_nets.sep(')
if count:
    content = content.replace('nbl_nets.sep(', 'nbl_nets.merged.sep(')
    with open(fname, 'w') as f:
        f.write(content)
    print("[INFO] Merged the first input of %d nBuLay check(s) in %s" % (count, fname))
else:
    print("[WARN] nBuLay checks not patched in %s (already fixed upstream?)" % fname)
PYEOF
else
    echo "[WARN] nBuLay DRC rule deck not found at $NBULAY_DRC"
fi

# Remove testing folders to save space
echo "[INFO] Removing unnecessary files to save space."
cd "$PDK_ROOT/$PDK"
find . -name "testing" -print0 | xargs -0 rm -rf

# Remove mdm files from doc folder to save space
cd "$PDK_ROOT/$PDK/libs.doc"
find . -name "*.mdm" -print0 | xargs -0 rm -rf

# Remove measurement folder to save space
rm -rf "$PDK_ROOT/$PDK/libs.doc/meas"

# gzip Liberty (.lib) files
bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/$PDK"

# Perform required preparation of IHP PDK for use with VACASK
echo "[INFO] Preparing IHP PDK for VACASK."
cd /tmp || exit 1

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

OPENVAF_DIR=${TOOLS}/openvaf/bin PYTHONPATH=/tmp/${VACASK_NAME}/python \
    python3 -m sg13g2tovc --openvaf-options --target_cpu generic
cp /tmp/${VACASK_NAME}/demo/ihp-sg13g2/.vacaskrc.toml "$PDK_ROOT/$PDK/libs.tech/vacask/.vacaskrc.toml"

cd /tmp || exit 1
rm -rf "${VACASK_NAME}"

# Remove *.orig files created during PDK preparation
find "$PDK_ROOT/$PDK/libs.tech/xschem" "$PDK_ROOT/$PDK/libs.ref/sg13g2_stdcell/sym" -name "*.orig" -delete

echo "[INFO] IHP SG13G2 PDK installation complete."
