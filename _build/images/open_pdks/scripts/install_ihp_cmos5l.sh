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
# a KLayout minimum. Keep SG13G2's file and raise just the klayout line to the
# stricter of the two, so neither PDK's gate is silently weakened when they drift.
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

# Rebuild the CMOS5L-own Verilog-A models for ngspice, the same way
# install_ihp.sh does for SG13G2: in-image and with --compile-model-generic, so
# the resulting OSDI runs on any host CPU. The PDK repo ships a prebuilt
# cap_cmomi.osdi, but it comes from whoever committed it (unknown OpenVAF version
# and target CPU), so it is not trustworthy for the image. psp103 and r3_cmc are
# symlinks into SG13G2 and are already compiled by install_ihp.sh.
# NOTE: this is the ngspice copy in libs.tech/ngspice/osdi. The VACASK copies in
# libs.tech/vacask/osdi are built separately further down.
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
import re
import sys
from ng2vclib.converter import Converter
from ng2vclib import dfl

pdkroot, pdk = sys.argv[1], sys.argv[2]

PARAM_ASSIGN = re.compile(r'([A-Za-z_]\w*)\s*=\s*(\S+)')
NUMBER = re.compile(r'[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?[a-zA-Z]*$')


def literalize_subckt_defaults(path):
    """Resolve symbolic subckt parameter defaults into plain literals.

    VACASK treats a subckt parameter whose DEFAULT references another
    parameter as derived, and then refuses to let an instance override it
    ("Parameter 'feed' not found."). ngspice has no such rule, so the IHP
    model files legitimately write cap_cmomi's feed default symbolically
    (".param none=0 same=1 double=2" plus "feed=double") and the converter
    carries that over verbatim. The result silently locks feed to 'double'
    for every VACASK user, and breaks the xschem VACASK flow outright: the
    spectre_format= line on cap_cmomi.sym always emits feed=<token>.

    Substituting the file-level constants back in keeps the same defaults
    while making the parameter a literal, hence overridable again. Written
    against the shape the converter emits ("parameters <name>=<value>",
    one or more per line, subckt bodies delimited by subckt/ends) rather
    than against a device name, so a renamed or added device is covered too.
    """
    with open(path) as f:
        lines = f.readlines()

    # Pass 1: collect the file-level (outside any subckt) numeric constants.
    consts = {}
    depth = 0
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('subckt'):
            depth += 1
        elif stripped.startswith('ends'):
            depth = max(0, depth - 1)
        elif depth == 0 and stripped.startswith('parameters'):
            for name, value in PARAM_ASSIGN.findall(stripped[len('parameters'):]):
                if NUMBER.match(value):
                    consts[name] = value

    if not consts:
        return 0

    # Pass 2: inside subckt bodies, replace a default that is exactly one of
    # those constants. Anything more involved (a real expression) is left
    # alone -- it is not something this fixup can safely rewrite.
    substituted = 0
    depth = 0
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('subckt'):
            depth += 1
        elif stripped.startswith('ends'):
            depth = max(0, depth - 1)
        elif depth > 0 and stripped.startswith('parameters'):
            head, tail = stripped[:len('parameters')], stripped[len('parameters'):]
            for name, value in PARAM_ASSIGN.findall(tail):
                if value in consts:
                    tail = re.sub(r'\b%s\s*=\s*%s\b' % (re.escape(name), re.escape(value)),
                                  '%s=%s' % (name, consts[value]), tail, count=1)
                    substituted += 1
                    print(f"[INFO]   {os.path.basename(path)}: subckt parameter "
                          f"{name} default {value} -> {consts[value]}")
            if tail != stripped[len('parameters'):]:
                indent = line[:len(line) - len(line.lstrip())]
                lines[idx] = indent + head + tail + '\n'

    if substituted:
        with open(path, 'w') as f:
            f.writelines(lines)
    return substituted

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
    literalize_subckt_defaults(dst)
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

# ---------------------------------------------------------------------------
# TEMPORARY: xschem/VACASK glue for CMOS5L.
#
# sg13g2tovc.py patches xschem symbols and xschemrc only for ihp-sg13g2, so the
# CMOS5L-own symbols get no spectre_format= line and cap_cmomi cannot be
# netlisted for VACASK from xschem at all. This reuses the upstream patchers
# (xschem2vc + sg13g2tovc.patch_analog/patch_dig) rather than reimplementing
# them, so it can be dropped as one block once VACASK ships ihp-sg13cmos5l
# support. Symbols that are symlinks into ihp-sg13g2 are skipped -- they were
# already patched in place in the SG13G2 tree by install_ihp.sh.
# ---------------------------------------------------------------------------
echo "[INFO] Adding xschem VACASK support for CMOS5L."
PYTHONPATH="/tmp/${VACASK_NAME}/python" python3 - "$PDK_ROOT" "$PDK" "/tmp/${VACASK_NAME}" << 'PYEOF'
import os
import shutil
import sys

import xschem2vc
import sg13g2tovc

pdkroot, pdk, vacask_dir = sys.argv[1], sys.argv[2], sys.argv[3]
xschem_dir = os.path.join(pdkroot, pdk, "libs.tech", "xschem")

# (symbol directory, format= patcher)
sym_dirs = [
    ("sg13cmos5l_pr", sg13g2tovc.patch_analog),
    ("sg13cmos5l_stdcells", sg13g2tovc.patch_dig),
]

for subdir, patcher in sym_dirs:
    d = os.path.join(xschem_dir, subdir)
    if not os.path.isdir(d):
        print(f"[INFO] No {subdir} symbol directory, skipping.")
        continue
    own_syms = sorted(
        e.path for e in os.scandir(d)
        if e.name.endswith(".sym") and not e.is_symlink() and e.is_file()
    )
    print(f"Patching {len(own_syms)} CMOS5L-own symbols in {subdir}")
    for symfile in own_syms:
        xschem2vc.convert(symfile, patcher)

# xschemrc extension. The upstream Tcl is PDK-agnostic apart from the
# "Add VACASK models symbol" menu entry, which names the SG13G2 common include
# and a corner set CMOS5L does not have (no HBT).
tcl = open(os.path.join(vacask_dir, "python", "sg13g2xschem.tcl")).read()
tcl = tcl.replace('include \\"sg13g2_vacask_common.lib\\"',
                  'include \\"sg13cmos5l_vacask_common.lib\\"')
tcl = tcl.replace('include \\"cornerHBT.lib\\" section=hbt_typ\n',
                  'include \\"cornerDIO.lib\\" section=dio_tt\n'
                  'include \\"cornerPNP.lib\\" section=typ\n')

with open(os.path.join(xschem_dir, "xschem-vacask"), "w") as f:
    f.write(tcl)

# Append the VACASK block to xschemrc, keeping a pristine .orig so a rebuild
# does not stack the block twice.
xschemrc = os.path.join(xschem_dir, "xschemrc")
xschemrc_orig = xschemrc + ".vacask-orig"
if not os.path.isfile(xschemrc_orig):
    shutil.copy(xschemrc, xschemrc_orig)

with open(xschemrc_orig) as f:
    base = f.read()

with open(xschemrc, "w") as f:
    f.write(base)
    f.write("""
# VACASK support
if {[info exists PDK_ROOT]} {
  if {[info exists PDK]} {
    if {[file exists $PDK_ROOT/$PDK/libs.tech/xschem/xschem-vacask]} {
      source $PDK_ROOT/$PDK/libs.tech/xschem/xschem-vacask
    }
  }
}

# Netlist type
if {[info exists env(XSCHEM_NETLIST_TYPE)]} {
  puts "Netlist mode: $::env(XSCHEM_NETLIST_TYPE)"
  set netlist_type $::env(XSCHEM_NETLIST_TYPE)
} else {
  puts "Netlist mode: <default>"
}
""")
PYEOF

# Drop the symbol backups xschem2vc leaves behind. Its patcher is idempotent
# without them (an existing spectre_format= line is recomputed and replaced).
find "$PDK_ROOT/$PDK/libs.tech/xschem" -name "*.sym.orig" -delete

rm -rf "/tmp/${VACASK_NAME}"

# gzip Liberty (.lib) files. The SRAM Liberty files are symlinks into the
# SG13G2 PDK and are already compressed by install_ihp.sh.
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
