#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
set -e
set -o pipefail
export SCRIPT_DIR=$TOOLS/osic-multitool
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

# Remove .git directory to save space
rm -rf "$PDK_ROOT/$PDK/.git"

# Add custom bindkeys for Magic
echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"
echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"

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


# Perform required preparation of IHP CMOS5L PDK for use with VACASK.
# CMOS5L reuses SG13G2's converted models/OSDI (installed by install_ihp.sh)
# for everything it symlinks; only the CMOS5L-own ngspice model files below
# need converting to VACASK format. None of them require Verilog-A/OSDI
# compilation (diodes, pnpMPA BJT, cap_mfringe are plain SPICE subckts/models).
echo "[INFO] Preparing IHP CMOS5L PDK for VACASK."
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
    "cap_mfringe.lib",
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

# Create .vacaskrc.toml. CMOS5L's own converted models plus SG13G2's
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
module_path_prefix = [ "\$(PDK_ROOT)/ihp-sg13g2/libs.tech/vacask/osdi" ]
EOF

rm -rf "/tmp/${VACASK_NAME}"

echo "[INFO] IHP SG13CMOS5L PDK installation complete."
