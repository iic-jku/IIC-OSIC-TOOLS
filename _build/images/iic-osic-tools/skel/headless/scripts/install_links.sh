#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Create symlinks for all installed tools
for binfile in "${TOOLS}"/*/bin/*; do
    # Skip Python venvs: their bin/ holds generic names (python, python3, pip,
    # activate, ...) which would hijack $TOOLS/bin, and $TOOLS/bin comes early
    # in PATH. The real entry points get wrappers further below.
    if [ -f "$(dirname "$(dirname "$binfile")")/pyvenv.cfg" ]; then
        continue
    fi
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

# Install wrapper for Surfer to fix crashes on remote X servers (XQuartz on
# macOS in X11 mode). Surfer's eframe tries GLX before EGL; GLX is unusable
# against XQuartz (Mesa finds no matching drisw fbconfig -> indirect GLX ->
# OpenGL 1.4 -> GLXBadFBConfig panic), so the libGL stub forces the working
# EGL path. On TCP displays MIT-SHM presentation is additionally disabled
# (SHM attach always fails across the VM boundary, which Mesa does not
# handle, leaving the window blank).
rm -f "${TOOLS}"/bin/surfer
# shellcheck disable=SC2016
echo '#!/bin/bash
export LD_LIBRARY_PATH="${TOOLS}/surfer/lib/noglx${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
case "${DISPLAY}" in
    :*|unix:*) ;; # local X server, MIT-SHM works
    *) export LD_PRELOAD="${TOOLS}/surfer/lib/libnoshm.so${LD_PRELOAD:+:${LD_PRELOAD}}" ;;
esac
exec -a "$0" "${TOOLS}/surfer/bin/surfer" "$@"' > "${TOOLS}"/bin/surfer
chmod +x "${TOOLS}"/bin/surfer

# Install wrappers for the tools living in Python venvs (skipped by the symlink
# loop above). The container exports a global PYTHONPATH seeded with the system
# interpreter's sys.path, and PYTHONPATH always precedes a venv's own
# site-packages -- so venv-pinned dependencies are shadowed by the system ones.
# CharLib requires the PySpice fork (git+https://github.com/infinitymdm/PySpice)
# which provides top-level PySpice.Circuit/.Simulator/.Unit; without unsetting
# PYTHONPATH it imports the system PySpice 1.5 instead and every run dies with
# "AttributeError: module 'PySpice' has no attribute 'Circuit'".
for venvbin in charlib cir2py; do
    rm -f "${TOOLS}/bin/${venvbin}"
    # shellcheck disable=SC2016
    printf '#!/bin/bash\nunset PYTHONPATH\nexec -a "$0" "%s" "$@"\n' \
        "${TOOLS}/charlib/bin/${venvbin}" > "${TOOLS}/bin/${venvbin}"
    chmod +x "${TOOLS}/bin/${venvbin}"
done
