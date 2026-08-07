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

# CMOS5L has symlinks to SG13G2 (OSDI models, Xyce plugins, xschem libs)
if [ ! -d "$PDK_ROOT/ihp-sg13g2" ]; then
    echo "[ERROR] IHP SG13G2 PDK not found at $PDK_ROOT/ihp-sg13g2."
    echo "[ERROR] Please install SG13G2 first, as CMOS5L depends on it."
    exit 1
fi

# Install IHP-SG13CMOS5L
PDK="ihp-sg13cmos5l"
IHP_CMOS5L_REPO_URL="https://github.com/iic-jku/ihp-sg13cmos5l.git"

echo "[INFO] Installing IHP SG13CMOS5L PDK."
git clone "$IHP_CMOS5L_REPO_URL" ihp-cmos5l
cd ihp-cmos5l || exit 1

# Store git hash of installed PDK version for reference
PDK_COMMIT=$(git rev-parse HEAD)

# Now move to the proper location
cd /tmp || exit 1
if [ -d ihp-cmos5l ]; then
	mv ihp-cmos5l "$PDK_ROOT/$PDK"
else
	echo "[ERROR] PDK directory 'ihp-cmos5l' not found after clone!"
	exit 1
fi

# Store git hash
echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# Reconcile the repo-level versions.txt used by the KLayout DRC/LVS version check.
# run_drc.py resolves it as <PDK_ROOT>/versions.txt (Path(__file__).parents[5]),
# so one file has to serve both PDKs. install_ihp.sh already installed SG13G2's
# copy, which carries entries for every tool; CMOS5L ships its own declaring only
# a (currently higher) KLayout minimum. Keep SG13G2's file and raise just the
# klayout line to the stricter of the two, so neither PDK's gate is weakened.
SHARED_VERSIONS="$PDK_ROOT/versions.txt"
CMOS5L_VERSIONS="$PDK_ROOT/$PDK/versions.txt"
if [ -f "$SHARED_VERSIONS" ] && [ -f "$CMOS5L_VERSIONS" ]; then
	python3 - "$SHARED_VERSIONS" "$CMOS5L_VERSIONS" << 'PYEOF'
import re
import sys

def klayout_version(path):
    with open(path, 'r') as f:
        for line in f:
            match = re.match(r'\s*klayout\s+(\S+)', line)
            if match:
                return match.group(1)
    return None

def sort_key(version):
    return tuple(int(part) for part in re.findall(r'\d+', version))

shared_path, own_path = sys.argv[1], sys.argv[2]
shared, own = klayout_version(shared_path), klayout_version(own_path)

if shared is None or own is None:
    print(f"[WARN] klayout entry missing (shared={shared}, cmos5l={own}), "
          f"leaving {shared_path} untouched")
    sys.exit(0)
if sort_key(own) <= sort_key(shared):
    print(f"[INFO] {shared_path} already requires klayout {shared} >= {own}")
    sys.exit(0)

with open(shared_path, 'r') as f:
    content = f.read()
content = re.sub(r'(?m)^(\s*klayout\s+)\S+', lambda m: m.group(1) + own, content, count=1)
with open(shared_path, 'w') as f:
    f.write(content)
print(f"[INFO] Raised klayout requirement in {shared_path} from {shared} to {own}")
PYEOF
else
	echo "[WARN] versions.txt not found (shared: $SHARED_VERSIONS, CMOS5L: $CMOS5L_VERSIONS)."
	echo "[WARN] The KLayout DRC/LVS version check may use the wrong minimum."
fi

# Remove .git directory to save space
rm -rf "$PDK_ROOT/$PDK/.git"

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

# Remove testing folders to save space
echo "[INFO] Removing unnecessary files to save space."
cd "$PDK_ROOT/$PDK"
find . -name "testing" -print0 | xargs -0 rm -rf

# Remove *.orig files created during PDK preparation
find "$PDK_ROOT/$PDK/libs.tech/xschem" -name "*.orig" -delete

# Add missing symlinks from CMOS5L pycell_lib to SG13G2 pycell_lib
# The CMOS5L PDK uses symlinks to SG13G2 PCell code (e.g. nmos_code.py),
# but some new dependencies (device_base_code.py, guard_ring_code.py) added
# upstream in SG13G2 are not yet symlinked in the CMOS5L repo.
CMOS5L_IHP="$PDK_ROOT/$PDK/libs.tech/klayout/python/sg13cmos5l_pycell_lib/ihp"
SG13G2_IHP="../../../../../../ihp-sg13g2/libs.tech/klayout/python/sg13g2_pycell_lib/ihp"
for pyfile in device_base_code.py guard_ring_code.py; do
    if [ ! -e "$CMOS5L_IHP/$pyfile" ] && [ -e "$PDK_ROOT/ihp-sg13g2/libs.tech/klayout/python/sg13g2_pycell_lib/ihp/$pyfile" ]; then
        ln -s "$SG13G2_IHP/$pyfile" "$CMOS5L_IHP/$pyfile"
        echo "[INFO] Created missing symlink: $pyfile"
    fi
done

# Compile the CMOS5L-own Verilog-A models, the same way install_ihp.sh does for
# SG13G2: in-image and with --compile-model-generic, so the resulting OSDI runs
# on any host CPU. The PDK repo ships a prebuilt cap_cmomi.osdi, but it is built
# by whoever committed it (unknown openvaf version and target CPU), so rebuild it
# against the image toolchain. psp103 and r3_cmc are symlinks into SG13G2 and are
# already compiled by install_ihp.sh.
echo "[INFO] Compiling Verilog-A models."
export PATH="$TOOLS/openvaf/bin:$PATH"
# Drop the prebuilt object first: openvaf-compile-va.sh does not set -e, so
# without this the check below would happily pass on the stale shipped file.
rm -f "$PDK_ROOT/$PDK/libs.tech/ngspice/osdi/cap_cmomi.osdi"
cd "$PDK_ROOT/$PDK/libs.tech/verilog-a" || exit 1
chmod +x openvaf-compile-va.sh
./openvaf-compile-va.sh --compile-model-generic
if [ ! -f "$PDK_ROOT/$PDK/libs.tech/ngspice/osdi/cap_cmomi.osdi" ]; then
	echo "[ERROR] OpenVAF model compilation for ngspice failed!"
	exit 1
fi

# Perform required preparation of IHP CMOS5L PDK for use with VACASK.
# CMOS5L reuses SG13G2's converted models/OSDI (installed by install_ihp.sh)
# for everything it symlinks; only the CMOS5L-own ngspice model files below
# need converting to VACASK format. Only the MoM capacitor cap_cmomi is a
# Verilog-A/OSDI device; it gets a second, VACASK-targeted module built below
# (the ngspice one was compiled further up). The others (diodes, pnpMPA BJT) are
# plain SPICE subckts/models.
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

PYTHONPATH="/tmp/${VACASK_NAME}/python" python3 - "$PDK_ROOT" "$PDK" << 'PYEOF'
import os
import sys
from ng2vclib.converter import Converter
from ng2vclib import dfl

pdkroot, pdk = sys.argv[1], sys.argv[2]

# CMOS5L-own ngspice model files (everything else in this dir is a symlink
# into ihp-sg13g2, already converted by sg13g2tovc.py during install_ihp.sh)
own_files = [
    "diodes.lib",
    "sg13cmos5l_pnpMPA_mod.lib",
    "sg13cmos5l_pnpMPA_stat.lib",
    # The MoM cap was renamed twice upstream: cap_mfringe -> cap_mom -> cap_cmomi
    # (to match SG13G2). cap_cmomi.lib is a wrapper subckt around the OSDI module
    # compiled below.
    "cap_cmomi.lib",
]

tech_src = os.path.join(pdkroot, pdk, "libs.tech", "ngspice", "models")
sg13g2_tech_src = os.path.join(pdkroot, "ihp-sg13g2", "libs.tech", "ngspice", "models")

cfg = dfl.default_config()
cfg["sourcepath"] = [tech_src, sg13g2_tech_src]
cfg["read_depth"] = 1
cfg["process_depth"] = 1
cfg["output_depth"] = None
cfg["default_model_prefix"] = "sg13cmos5l_default_mod_"
cfg["signature"] = "// Converted from IHP SG13CMOS5L PDK for Ngspice\n"

for fname in own_files:
    src = os.path.join(tech_src, fname)
    dst = os.path.join(pdkroot, pdk, "libs.tech", "vacask", "models", fname)
    print(f"Converting {src} -> {dst}")
    Converter(cfg).convert(src, dst)
PYEOF

# Build the cap_cmomi OSDI module for VACASK. The build above produces the
# ngspice copy in libs.tech/ngspice/osdi (compiled with -D__NGSPICE__ by the PDK
# script), so compile a separate one here for the VACASK module path.
# cap_cmomi.va has no __NGSPICE__ guards (only __XYCE__, which stays undefined),
# so the same source yields an equivalent module for VACASK.
CMOS5L_VA="$PDK_ROOT/$PDK/libs.tech/verilog-a/cap_cmomi/cap_cmomi.va"
if [ -f "$CMOS5L_VA" ]; then
	echo "[INFO] Compiling cap_cmomi Verilog-A to OSDI for VACASK."
	mkdir -p "$PDK_ROOT/$PDK/libs.tech/vacask/osdi"
	"$TOOLS/openvaf/bin/openvaf" --target_cpu generic \
		-o "$PDK_ROOT/$PDK/libs.tech/vacask/osdi/cap_cmomi.osdi" "$CMOS5L_VA"
else
	echo "[WARN] cap_cmomi Verilog-A not found at $CMOS5L_VA, skipping OSDI build."
fi

# Create .vacaskrc.toml. CMOS5L's own converted models and OSDI plus SG13G2's
# converted models/stdcell/io/OSDI are all needed since most CMOS5L devices
# are symlinks to SG13G2.
echo "[INFO] Creating sample .vacaskrc.toml"
cat > "$PDK_ROOT/$PDK/libs.tech/vacask/.vacaskrc.toml" << EOF
# VACASK configuration file
[Paths]
include_path_prefix = [
  "\$(PDK_ROOT)/\$(PDK)/libs.tech/vacask/models",
  "\$(PDK_ROOT)/ihp-sg13g2/libs.tech/vacask/models",
  "\$(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/vacask",
  "\$(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/vacask"
]
module_path_prefix = [
  "\$(PDK_ROOT)/\$(PDK)/libs.tech/vacask/osdi",
  "\$(PDK_ROOT)/ihp-sg13g2/libs.tech/vacask/osdi"
]
EOF

rm -rf "/tmp/${VACASK_NAME}"

# CMOS5L is largely symlinks into SG13G2, so a rename on the SG13G2 side silently
# leaves a broken link behind (this is how libs.tech/xyce/models/resistors.lib
# went stale). Report them instead of failing the build, since a dangling link is
# a PDK-side fix and not every one of them blocks the tools.
echo "[INFO] Checking for broken symlinks into SG13G2."
BROKEN_LINKS=$(find "$PDK_ROOT/$PDK" -xtype l || true)
if [ -n "$BROKEN_LINKS" ]; then
	echo "[WARN] Broken symlinks found in $PDK:"
	echo "$BROKEN_LINKS" | sed 's/^/[WARN]   /'
else
	echo "[INFO] No broken symlinks found."
fi

echo "[INFO] IHP SG13CMOS5L PDK installation complete."
