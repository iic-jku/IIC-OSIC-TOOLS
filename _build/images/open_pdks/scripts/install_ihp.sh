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
# CMOS5L ships its own copy of this file, so the fix lives in a shared helper
# that install_ihp_cmos5l.sh runs as well.
echo "[INFO] Fixing KLayout netlist import templates."
TEMPLATES_FILE="$PDK_ROOT/$PDK/libs.tech/klayout/python/import_netlist/ihp130_pcell_templates.py"
if [ -f "$TEMPLATES_FILE" ]; then
    python3 "$PDK_SCRIPT_DIR/fix_netlist_templates.py" "$TEMPLATES_FILE"
else
    echo "[WARN] KLayout netlist import templates not found at $TEMPLATES_FILE"
fi

# Anchor the KLayout GUI DRC/LVS run directory to the layout file. The IHP menu
# macros expand a relative run_dir against the working directory of the KLayout
# process, so the same layout writes its reports to a different place depending
# on how KLayout was started, and by default next to the GDS. The helper also
# adds a %top_cell% placeholder, so one setting such as
# ../verification/drc/%top_cell%.klayout.drc serves every cell of a project.
# CMOS5L ships its own copies of these four macros rather than symlinks, so the
# fix lives in a shared helper that install_ihp_cmos5l.sh runs as well.
echo "[INFO] Fixing the KLayout GUI DRC/LVS run directory."
python3 "$PDK_SCRIPT_DIR/fix_klayout_run_dir.py" "$PDK_ROOT/$PDK/libs.tech/klayout/tech/macros"

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

# The sealring PCell stamps the PDK version into a label and obtains it by
# shelling out to `git rev-parse` inside the PDK tree. There is no .git there
# (SG13G2 is moved out of the clone above, CMOS5L deletes its own), so git prints
# "fatal: not a git repository" to stderr on every sealring instantiation and the
# label ends up as "Unknown (Not a Git repo or Git not installed)". Use
# the COMMIT file both IHP installers write next to the PDK instead, keep git as
# the fallback with its stderr muted, and catch more than CalledProcessError --
# a missing git binary raises an uncaught FileNotFoundError today. CMOS5L
# symlinks this file into SG13G2, so patching it here covers both PDKs.
echo "[INFO] Fixing the sealring PDK version lookup."
UTILITY_FUNCTIONS="$PDK_ROOT/$PDK/libs.tech/klayout/python/sg13g2_pycell_lib/ihp/utility_functions.py"
if [ -f "$UTILITY_FUNCTIONS" ]; then
    python3 - "$UTILITY_FUNCTIONS" << 'PYEOF'
import re
import sys

fname = sys.argv[1]
with open(fname, 'r') as f:
    content = f.read()

if 'commit_file' in content:
    print("[INFO] Sealring PDK version lookup already patched in %s" % fname)
    sys.exit(0)

# 1. Prefer the COMMIT file written by the installer. Walk up from the module
#    towards the PDK root rather than hardcoding a depth, so this keeps working
#    for the CMOS5L symlink and if the tree is ever rearranged.
anchor = "        script_dir = os.path.dirname(script_path)\n"
lookup = anchor + """
        # The PDK is installed without its .git, so prefer the COMMIT file the
        # installer writes next to it (see install_ihp.sh).
        probe = script_dir
        for _ in range(8):
            probe = os.path.dirname(probe)
            commit_file = os.path.join(probe, "COMMIT")
            if os.path.isfile(commit_file):
                with open(commit_file) as f:
                    return f.read().strip()
"""
n_lookup = content.count(anchor)
content = content.replace(anchor, lookup)

# 2. Keep git as the fallback, but do not let it write to the console.
content, n_stderr = re.subn(
    r"(\['git', '-C', \w+, 'rev-parse', [^\]]+\])\n(\s*)\)",
    r"\1, stderr=subprocess.DEVNULL\n\2)",
    content,
)

# 3. A missing git binary raises FileNotFoundError, which is not caught today.
content, n_except = re.subn(
    r'except subprocess\.CalledProcessError:',
    'except Exception:',
    content,
)

if n_lookup and n_stderr == 2 and n_except:
    with open(fname, 'w') as f:
        f.write(content)
    print("[INFO] Fixed the sealring PDK version lookup in %s" % fname)
else:
    print("[WARN] Sealring PDK version lookup not patched in %s "
          "(already fixed upstream?)" % fname)
PYEOF
else
    echo "[WARN] KLayout PCell utility functions not found at $UTILITY_FUNCTIONS"
fi

# isolbox defaults its length and width to techparams['isolbox_defLW'] = 3u,
# while its own callback clamps both to 3.6u for the default wellwidth of 1.05u
# (callbacks/isolbox_cb.tcl). Every instantiation with default parameters
# therefore prints "WARNING: wrong width/length: using minimum ... 3.6u!!". The
# neighbouring defaults in isolbox_code.py already assume 3.6u (defA = 12.96p =
# 3.6 x 3.6, defP = 14.4u = 2 x (3.6 + 3.6)), so the tech parameter is simply
# stale. SG13G2 only: CMOS5L ships no isolbox.
echo "[INFO] Fixing the isolbox default length/width."
for tech_json in sg13g2_tech.json sg13g2_tech_mod.json; do
    TECH_JSON="$PDK_ROOT/$PDK/libs.tech/klayout/python/sg13g2_pycell_lib/$tech_json"
    if [ ! -f "$TECH_JSON" ]; then
        echo "[WARN] KLayout PCell tech parameters not found at $TECH_JSON"
    elif grep -q '"isolbox_defLW": *"3u"' "$TECH_JSON"; then
        sed -i 's/"isolbox_defLW": *"3u"/"isolbox_defLW": "3.6u"/' "$TECH_JSON"
        echo "[INFO] Set isolbox_defLW to 3.6u in $TECH_JSON"
    else
        echo "[WARN] isolbox_defLW not patched in $TECH_JSON (already fixed upstream?)"
    fi
done

# The CNI foreground booleans (dbLayerXor and friends, see ihp/geometry.py)
# consume their operands, and several PCells destroy those operands again right
# afterwards. The second destroy() is a no-op on correct geometry, but it logs a
# warning, and the ~35 lines of "Box.destroy: already destroyed!" per run bury
# the messages that matter. Demote them from Logger.warn to Logger.log, the only
# one of the three that is verbosity-gated (Logger.info still prints at the
# default verbosity of 0), so the message stays available with `klayout -d`.
# Dropping the redundant destroy() calls scattered over the PCell sources is
# upstream's to make.
# CMOS5L symlinks the whole pycell4klayout-api tree, so this covers both PDKs.
echo "[INFO] Demoting the CNI double-destroy warnings."
CNI_DIR="$PDK_ROOT/$PDK/libs.tech/klayout/python/pycell4klayout-api/source/python/cni"
if [ -d "$CNI_DIR" ]; then
    for cni_file in box ellipse path polygon text; do
        CNI_FILE="$CNI_DIR/$cni_file.py"
        if [ -f "$CNI_FILE" ] && grep -q 'pya.Logger.warn(f".*already destroyed!")' "$CNI_FILE"; then
            sed -i 's/pya\.Logger\.warn(\(f".*already destroyed!"\))/pya.Logger.log(\1)/' "$CNI_FILE"
            echo "[INFO] Demoted the double-destroy warning in $CNI_FILE"
        fi
    done
else
    echo "[WARN] CNI shape classes not found at $CNI_DIR"
fi

# The parallel-simulation launchers in the xschem test schematics call
# "python3 <script>" straight from Tcl -- same class of defect as the `mkdir -p`
# that was fixed in xschem-menu (IHP-Open-PDK 96fe2b70). It only appears to work
# when xschem is started in a terminal foreground: Tk_Main() then sets
# tcl_interactive to 1 and Tcl's `unknown` handler auto-executes external
# programs. Started detached -- from sak-open, the desktop entry, or with
# `xschem &` -- tcl_interactive stays 0 and the launcher dies with
# `invalid command name "python3"`.
# `exec >&@stdout` is what the auto-exec fallback does: run the program with its
# output going to xschem's stdout, rather than capturing it and turning anything
# the child writes to stderr into a Tcl error (which plain `exec` would do).
echo "[INFO] Fixing the parallel-simulation launchers in the xschem test schematics."
for tb in inv_mc_tb.sch inv_sweep_tb.sch isolbox_sweep_tb.sch; do
	TB_FILE="$PDK_ROOT/$PDK/libs.tech/xschem/sg13g2_tests/$tb"
	if [ ! -f "$TB_FILE" ]; then
		echo "[WARN] xschem test schematic not found at $TB_FILE"
	elif grep -q '^python3 ' "$TB_FILE"; then
		sed -i 's|^python3 |exec >\&@stdout python3 |' "$TB_FILE"
		echo "[INFO] Fixed the python3 launcher in $TB_FILE"
	else
		echo "[WARN] No bare 'python3' launcher in $TB_FILE (already fixed upstream?)"
	fi
done

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
