#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
set -o pipefail
export SCRIPT_DIR=$TOOLS/osic-multitool
PDK_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# Install ciel via pip
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	ciel

####################
# INSTALL SKY130 PDK
####################

echo "[INFO] Installing SKY130 PDK."
ciel enable "${OPEN_PDKS_REPO_COMMIT}" --pdk sky130

# Remove sky130B for size reasons
rm -rf "$PDK_ROOT"/ciel/sky130/versions/*/sky130B
rm -rf "$PDK_ROOT"/sky130B

if [ ! -d "$PDK_ROOT/sky130A" ]; then
	echo "[ERROR] sky130A not found after ciel enable!"
	exit 1
fi

if [ -d "$PDK_ROOT/sky130A" ]; then
	# gzip Liberty (.lib) files
	bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/sky130A"

	# Add custom bindkeys for Magic
    echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"
    echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"

	# Repair the KLayout tech file shipped by open_pdks: it still carries the
	# generic "sky130" tech/layer-property naming and the absolute base paths of
	# the machine the PDK was built on. All four edits are idempotent; the guard
	# only exists so we notice when the workaround becomes unnecessary (still
	# needed as of 2026-08-06).
	SKY130A_LYT="$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	if grep -q -e '>sky130<' -e 'sky130\.lyp' -e '<base-path>' "$SKY130A_LYT"; then
		sed -i 's/>sky130</>sky130A</g' "$SKY130A_LYT"
		sed -i 's/sky130.lyp/sky130A.lyp/g' "$SKY130A_LYT"
		sed -i '/<base-path>/c\ <base-path/>' "$SKY130A_LYT"
		# shellcheck disable=SC2016
		sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$SKY130A_LYT"
	else
		echo "[INFO] sky130A.lyt needs no repair anymore, this patch can be dropped"
	fi

	# Patch the pcells for compatibility with gdsfactory >= 8.x / kfactory >= 1.x
	# so they work with the current system gdsfactory (no dedicated venv needed).
	if [ -d "$PDK_ROOT/sky130A/libs.tech/klayout/python/cells" ]; then
		# gdsfactory >= 8 does not support the "A-B" boolean operation string
		# anymore; use "-" instead. Some occurrences are spelled 'operation= "A-B"'.
		find "$PDK_ROOT/sky130A/libs.tech/klayout/python/cells" -name "*.py" \
			-exec sed -i 's/operation= *"A-B"/operation="-"/g' {} \;

		# cells/pdk.py was written against kfactory 0.x internals: the private
		# _get_default_kcl() and KCell._kdb_cell were removed in kfactory >= 1.x,
		# and kfactory >= 1.x locks cells produced by cached cell functions, which
		# breaks the scale_and_snap grid snapping in take_component().
		python3 - "$PDK_ROOT/sky130A/libs.tech/klayout/python/cells/pdk.py" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    src = f.read()

old = "  kf.kcell._get_default_kcl().clear()\n"
new = """  # kfactory >= 1.x removed the private _get_default_kcl(); the default
  # layout is available as kf.kcl there.
  try:
    kf.kcell._get_default_kcl().clear()
  except AttributeError:
    kf.kcl.clear()
"""
assert old in src, "pdk.py: _get_default_kcl pattern not found"
src = src.replace(old, new)

old = "  source_cell = c._kdb_cell\n"
new = """  # kfactory >= 1.x exposes the native cell as the public kdb_cell property.
  source_cell = getattr(c, "kdb_cell", None)
  if source_cell is None:
    source_cell = c._kdb_cell

  # kfactory >= 1.x locks cells produced by cached cell functions; unlock
  # them so scale_and_snap below may modify the cell tree.
  for cell in source_cell.layout().each_cell():
    if cell.locked:
      cell.locked = False
"""
assert old in src, "pdk.py: _kdb_cell pattern not found"
src = src.replace(old, new)

with open(path, "w") as f:
    f.write(src)
PYEOF

		# gdsfactory 9 removed Component.add_array, and gdsfactory >= 9.29 no
		# longer auto-activates the generic PDK (the CONF.pdk default changed
		# from "generic" to None), which the drawing code relies on for layer
		# resolution. Both shims are no-ops on older gdsfactory versions.
		cat >> "$PDK_ROOT/sky130A/libs.tech/klayout/python/cells/__init__.py" <<'PYEOF'


def _gf9_compat():
    from typing import Optional

    import gdsfactory as gf

    def _add_array(self, component, columns=2, rows=2,
                   spacing=(100, 100), alias: Optional[str] = None):
        return self.add_ref(component=component, name=alias,
                            columns=columns, rows=rows,
                            column_pitch=spacing[0], row_pitch=spacing[1])

    if not hasattr(gf.Component, "add_array"):
        gf.Component.add_array = _add_array

    # The container always exports PDK=<klayout-pdk-name> (e.g. sky130A).
    # gdsfactory maps $PDK into CONF.pdk, so get_active_pdk() does not take the
    # clean "no active PDK -> ValueError" path; instead it tries to import a
    # gdsfactory PDK plugin literally named "sky130A". No such plugin exists
    # (these are KLayout-native pcells), so it raises ModuleNotFoundError and the
    # tech aborts with "no PDK info found for tech". Fall back to the generic PDK
    # (used only for layer-tuple resolution) on any failure, without overriding a
    # real PDK the user may have activated beforehand.
    try:
        gf.get_active_pdk()
    except Exception:
        gf.gpdk.PDK.activate()


_gf9_compat()
PYEOF
	fi
fi

if [ -d "$PDK_ROOT/sky130B" ]; then
	# gzip Liberty (.lib) files
	bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/sky130B"

    echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc"
    echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc"

	sed -i 's/>sky130</>sky130B</g' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	sed -i 's/sky130.lyp/sky130B.lyp/g' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	sed -i '/<base-path>/c\ <base-path/>' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	# shellcheck disable=SC2016
	sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
fi

######################
# INSTALL GF180MCU PDK
######################

echo "[INFO] Installing GF180 PDK."
ciel enable "${OPEN_PDKS_REPO_COMMIT}" --pdk-family gf180mcu

# Remove gf180mcuA, gf180mcuB and gf180mcuC for size reasons
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuA
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuB
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuC
rm -rf "$PDK_ROOT"/gf180mcuA
rm -rf "$PDK_ROOT"/gf180mcuB
rm -rf "$PDK_ROOT"/gf180mcuC

if [ ! -d "$PDK_ROOT/gf180mcuD" ]; then
	echo "[ERROR] gf180mcuD not found after ciel enable!"
	exit 1
fi

if [ -d "$PDK_ROOT/gf180mcuD" ]; then
	# gzip Liberty (.lib) files
	bash "$PDK_SCRIPT_DIR/gzip_liberty.sh" "$PDK_ROOT/gf180mcuD"

	cd "$PDK_ROOT/gf180mcuD/libs.tech/ngspice" || exit 1
	
	# Setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit

	# Remove testing folders to save space
	cd "$PDK_ROOT/gf180mcuD"
	find . -name "testing" -print0 | xargs -0 rm -rf

	# Fix test schematic relative paths
	sed -i 's/{test_/{tests\/test_/g' "$PDK_ROOT/gf180mcuD/libs.tech/xschem/tests/0_top.sch"

	# Fix missing PDK variant in path definitions for in xschemrc
	sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuD/libs.tech/ngspice|' "$PDK_ROOT/gf180mcuD/libs.tech/xschem/xschemrc"

	# Fix incorrect sky130 model reference in gf180mcuD xschem transistor symbols.
	# The OP annotation tcleval expressions incorrectly use msky130_fd_pr__@model
	# instead of m0 (the actual internal MOSFET element name in gf180mcu subcircuits).
	find "$PDK_ROOT/gf180mcuD/libs.tech/xschem" -name "*.sym" \
		-exec sed -i 's/msky130_fd_pr__@model/m0/g' {} \;

	# Port the bundled (gdsfactory v7 era) pcells to the current gdsfactory 9.x:
	#  - cells/_patches.py (new): runtime shims for removed v7 APIs (add_array,
	#    size, get_polygons(by_spec=...), connect(destination=...), geometry
	#    namespace, duplicate cell names) plus explicit generic-PDK activation
	#    (gdsfactory >= 9.29 no longer auto-activates it).
	#  - explicit defaults for all TypeList pcell parameters (KLayout batch API
	#    passes None otherwise, yielding silently empty pfet/via_dev devices).
	#  - fix the draw_via_dev() call in vias_gen.py (stray v7-era arguments).
	# See patches/gf180mcu-pcells-gdsfactory9.patch for the full change.
	(
		cd "$PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/pymacros" || exit 1
		git apply /images/open_pdks/patches/gf180mcu-pcells-gdsfactory9.patch
	)

    # Give universal write access to the macro directory, necessary for saving options
    # and creating the run directory.
    chmod -R 777 "$PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/macros"
fi

echo "[INFO] GF180 PDK installation complete."
