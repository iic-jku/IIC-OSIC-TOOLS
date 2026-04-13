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

# Install wrapper for AppCSXCAD to fix GLX context failure when LIBGL_ALWAYS_INDIRECT=1
# (set by start_x.sh). AppCSXCAD uses VTK which cannot create a GLX context in indirect mode.
# This wrapper overrides LIBGL_ALWAYS_INDIRECT=0 so that VTK can render correctly.
# A wrapper is used (not an alias) so that subprocess calls from Python scripts also benefit.
# see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/254
rm -f "${TOOLS}"/bin/AppCSXCAD
# shellcheck disable=SC2016
echo '#!/bin/bash
exec env LIBGL_ALWAYS_INDIRECT=0 "${TOOLS}/openems/bin/AppCSXCAD" "$@"' > "${TOOLS}"/bin/AppCSXCAD
chmod +x "${TOOLS}"/bin/AppCSXCAD
