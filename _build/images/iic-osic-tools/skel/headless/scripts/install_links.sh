#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Create symlinks for all installed tools
for binfile in "${TOOLS}"/*/bin/*; do
    linkname="${TOOLS}/bin/$(basename "$binfile")"
    if [[ "$binfile" == *librelane* ]]; then
        if [ ! -e "${linkname}-librelane" ]; then
            ln -s "$binfile" "${linkname}-librelane"
        fi
    else
        if [ ! -e "$linkname" ]; then
            ln -s "$binfile" "$linkname"
        fi
    fi
done

# Create symlink for Xyce (lowercase)
ln -s "${TOOLS}"/bin/Xyce "${TOOLS}"/bin/xyce

# Create symlink for GHDL and Slang Yosys plugins
ln -s "${TOOLS}/ghdl-yosys-plugin/ghdl.so" "${TOOLS}/yosys/share/yosys/plugins/ghdl.so"
ln -s "${TOOLS}/slang-yosys-plugin/slang.so" "${TOOLS}/yosys/share/yosys/plugins/slang.so"

# Install wrapper for Yosys so that modules are loaded automatically
# see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/43
rm -f "${TOOLS}"/bin/yosys
# shellcheck disable=SC2016
echo '#!/bin/bash
if [[ $1 == "-h" ]]; then
    exec -a "$0" "$TOOLS/yosys/bin/yosys" "$@"
else
    exec -a "$0" "$TOOLS/yosys/bin/yosys" -m ghdl -m slang "$@"
fi' > "${TOOLS}"/bin/yosys
chmod +x "${TOOLS}"/bin/yosys

# Install wrapper for librelane to set PATH correctly
# shellcheck disable=SC2016
echo '#!/bin/bash
export PATH=${TOOLS}/openroad-librelane/bin:${PATH} 
exec -a "$0" /usr/local/bin/librelane --manual-pdk "$@"' > "${TOOLS}"/bin/librelane
chmod +x "${TOOLS}"/bin/librelane

# Install wrapper for KLayout to unset PDK env var for gdsfactory-based PDKs.
# gdsfactory's pydantic-settings reads PDK from the environment and tries to import
# it as a Python module (e.g. 'import sky130A'). When this fails, KLayout's pcell
# libraries cannot initialize and KLayout reports "ERROR: no PDK info found for tech".
# Only sky130A/B and gf180mcuC/D use gdsfactory-based pcells, so PDK is only stripped
# for those. All other PDKs (e.g. ihp-sg13g2) receive PDK unchanged.
rm -f "${TOOLS}"/bin/klayout
# shellcheck disable=SC2016
echo '#!/bin/bash
case "$PDK" in
    sky130A|sky130B|gf180mcuC|gf180mcuD)
        exec env -u PDK "${TOOLS}/klayout/bin/klayout" "$@"
        ;;
    *)
        exec "${TOOLS}/klayout/bin/klayout" "$@"
        ;;
esac' > "${TOOLS}"/bin/klayout
chmod +x "${TOOLS}"/bin/klayout
