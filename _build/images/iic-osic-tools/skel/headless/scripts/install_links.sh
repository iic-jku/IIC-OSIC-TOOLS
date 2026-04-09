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

# Install wrapper for KLayout so that PDKs with legacy gdsfactory pcell libraries
# (sky130A, gf180mcuD) work correctly. When sak-pdk sets _IIC_KLAYOUT_PDK_VENV,
# this wrapper:
#   1. Sets KLAYOUT_VENV_SP to the gdsfactory8 venv site-packages path so that
#      sitecustomize.py (in $TOOLS/klayout/pymod/) injects it into KLayout's sys.path.
#   2. Strips PDK from KLayout's environment with 'env -u PDK' to prevent
#      gdsfactory's pydantic-settings from trying to import the PDK name as a Python module.
# shellcheck disable=SC2016
echo '#!/bin/sh
# KLayout wrapper: activates gdsfactory8 venv for PDKs with legacy pcell libraries.
# Set _IIC_KLAYOUT_PDK_VENV (via sak-pdk) to enable. See KNOWN_ISSUES.md.
if [ -n "$_IIC_KLAYOUT_PDK_VENV" ]; then
    _vsp=""
    for _d in "$_IIC_KLAYOUT_PDK_VENV"/lib/python*/site-packages; do
        [ -d "$_d" ] && _vsp="$_d" && break
    done
    exec env -u PDK KLAYOUT_VENV_SP="$_vsp" /foss/tools/klayout/klayout "$@"
fi
exec /foss/tools/klayout/klayout "$@"' > "${TOOLS}"/bin/klayout
chmod +x "${TOOLS}"/bin/klayout

# Install wrapper for librelane to set PATH correctly
# shellcheck disable=SC2016
echo '#!/bin/bash
export PATH=${TOOLS}/openroad-librelane/bin:${PATH} 
exec -a "$0" /usr/local/bin/librelane --manual-pdk "$@"' > "${TOOLS}"/bin/librelane
chmod +x "${TOOLS}"/bin/librelane
