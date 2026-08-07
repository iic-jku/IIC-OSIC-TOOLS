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
# for everything it symlinks; only the CMOS5L-own ngspice model files need
# converting to VACASK format. Those are discovered at build time as the
# regular files (as opposed to symlinks into ihp-sg13g2) in the ngspice model
# directory -- do NOT hardcode the list, upstream renames devices (cap_mfringe
# -> cap_mom -> cap_cmomi) and a stale list breaks the image build.
# CMOS5L-own Verilog-A sources, if any, are compiled to OSDI for VACASK below.
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

tech_src = os.path.join(pdkroot, pdk, "libs.tech", "ngspice", "models")
sg13g2_tech_src = os.path.join(pdkroot, "ihp-sg13g2", "libs.tech", "ngspice", "models")
dest_dir = os.path.join(pdkroot, pdk, "libs.tech", "vacask", "models")

# CMOS5L-own ngspice model files: every regular *.lib in the model directory.
# The rest are symlinks into ihp-sg13g2 and were already converted by
# sg13g2tovc.py during install_ihp.sh. Discovering them keeps this working
# across upstream device renames instead of failing the build on a stale name.
own_files = sorted(
    e.name for e in os.scandir(tech_src)
    if e.name.endswith(".lib") and not e.is_symlink() and e.is_file()
)

if not own_files:
    print("[ERROR] No CMOS5L-own ngspice model files found in " + tech_src)
    sys.exit(1)

os.makedirs(dest_dir, exist_ok=True)

for fname in own_files:
    # corner*.lib only wire up .include chains -- convert them like
    # sg13g2tovc.py does, i.e. keep the includes instead of inlining them
    corner = fname.startswith("corner")

    cfg = dfl.default_config()
    cfg["sourcepath"] = [tech_src, sg13g2_tech_src]
    cfg["read_depth"] = 0 if corner else 1
    cfg["process_depth"] = 0 if corner else 1
    cfg["output_depth"] = 0 if corner else None
    cfg["default_model_prefix"] = "sg13cmos5l_default_mod_"
    cfg["signature"] = "// Converted from IHP SG13CMOS5L PDK for Ngspice\n"

    src = os.path.join(tech_src, fname)
    dst = os.path.join(dest_dir, fname)
    print(f"Converting {src} -> {dst}")
    Converter(cfg).convert(src, dst)
PYEOF

# Compile the CMOS5L-own Verilog-A models to OSDI for VACASK. The .osdi objects
# shipped in libs.tech/ngspice/osdi are built for ngspice with stock OpenVAF and
# are not reused here, exactly as install_ihp.sh rebuilds the SG13G2 ones with
# openvaf-r. No -D__NGSPICE__: the CMOS5L sources only branch on __XYCE__, and
# the default branch is the $mfactor one that VACASK expects.
OPENVAF_BIN="${TOOLS}/openvaf/bin/openvaf-r"
VA_SRC_DIR="$PDK_ROOT/$PDK/libs.tech/verilog-a"
VACASK_OSDI_DIR="$PDK_ROOT/$PDK/libs.tech/vacask/osdi"
VACASK_COMMON="$PDK_ROOT/$PDK/libs.tech/vacask/models/sg13cmos5l_vacask_common.lib"

# Common include: pulls in the SG13G2 loads/default models (most CMOS5L devices
# are symlinks into SG13G2) and adds the CMOS5L-own OSDI loads on top.
echo '// Converted from IHP SG13CMOS5L PDK for Ngspice' >  "$VACASK_COMMON"
echo 'include "sg13g2_vacask_common.lib"'               >> "$VACASK_COMMON"

if [ -d "$VA_SRC_DIR" ]; then
	if [ ! -x "$OPENVAF_BIN" ]; then
		echo "[ERROR] OpenVAF not found at $OPENVAF_BIN, cannot build CMOS5L OSDI models."
		exit 1
	fi

	mkdir -p "$VACASK_OSDI_DIR"
	while IFS= read -r -d '' va_file; do
		osdi_name="$(basename "${va_file%.va}").osdi"
		echo "[INFO] Compiling $(basename "$va_file") -> $osdi_name for VACASK."
		"$OPENVAF_BIN" --target_cpu generic -o "$VACASK_OSDI_DIR/$osdi_name" "$va_file"
		echo "load \"$osdi_name\"" >> "$VACASK_COMMON"
	done < <(find "$VA_SRC_DIR" -name "*.va" -print0 | sort -z)
fi

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
module_path_prefix = [
  "\$(PDK_ROOT)/\$(PDK)/libs.tech/vacask/osdi",
  "\$(PDK_ROOT)/ihp-sg13g2/libs.tech/vacask/osdi"
]
EOF

rm -rf "/tmp/${VACASK_NAME}"

# gzip Liberty (.lib) files. The SRAM Liberty files are symlinks into the
# SG13G2 PDK and are already compressed by install_ihp.sh.
bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/$PDK"

echo "[INFO] IHP SG13CMOS5L PDK installation complete."
