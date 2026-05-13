# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
#
# Single source of truth for the IIC-OSIC-Tools shell environment.
# This file is sourced from /etc/profile (login shells) and from
# /headless/.bashrc (interactive shells); a guard prevents double init.

function _path_add_tool() {
    local tool_name=$1
    local d
    for d in "$TOOLS/$tool_name" ; do
        if [ -d "${d}" ]; then
            export PATH=$PATH:${d%/}
        fi
    done
}

function _path_add_tool_custom() {
    local custom_path=$1
    local d
    for d in "$TOOLS/$custom_path/" ; do
        if [ -d "${d}" ]; then
            export PATH=$PATH:${d%/}
        fi
    done
}

function _path_add_tool_python() {
    local tool_name=$1
    local d
    for d in "$TOOLS/$tool_name"/local/lib/python3*/dist-packages ; do
        if [ -d "${d}" ]; then
            export PYTHONPATH=$PYTHONPATH:${d}
        fi
    done
}

function _add_resolution () {
    # $1=X, $2=Y
    # Do only in VNC mode
    if [ -v VNCDESKTOP ]; then
        local x=$1 y=$2
        local mline mline_trim
        # and only when resolution not yet available
        if ! xrandr 2> /dev/null | awk '{print $1}' | grep -q "${x}x${y}"; then
            mline=$(cvt "$x" "$y" 60 | grep -oP '(?<=Modeline ).*')
            mline_trim=$(echo "$mline" | sed 's/^[^"]*"[^"]*"//')
            # shellcheck disable=SC2086
            xrandr --newmode "${x}x${y}" $mline_trim
            xrandr --addmode VNC-0 "${x}x${y}"
        fi
    fi
}

if [ -z "${FOSS_INIT_DONE+x}" ]; then
    _path_add_tool          "kactus2"
    _path_add_tool          "klayout"
    _path_add_tool_custom   "osic-multitool"

    export SAK=$TOOLS/sak
    export PATH=$TOOLS/bin:$SAK:/usr/local/sbin:$PATH

    # OpenROAD in Ubuntu 22.04 does not find the PIP modules, so use PYTHONPATH
    PYTHONPATH=$(python3 -c "import sys; print(':'.join(x for x in sys.path if x))") && export PYTHONPATH
    _path_add_tool_python "ngspyce"
    _path_add_tool_python "openems"
    _path_add_tool_python "pyopus"
    export PYTHONPATH=$PYTHONPATH:$TOOLS/yosys/share/yosys/python3
    export PYTHONPATH=$PYTHONPATH:$TOOLS/klayout/pymod
    export PYTHONPATH=$PYTHONPATH:$TOOLS/vacask/lib/vacask/python

    # Add local directories in $HOME so the user can upgrade PIP packages.
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    export PATH=$HOME/.local/bin:$PATH
    export PYTHONPATH=$HOME/.local/lib/python${PYTHON_VERSION}/site-packages:$PYTHONPATH
    unset PYTHON_VERSION

    # shellcheck disable=SC2086
    LD_LIBRARY_PATH="${TOOLS}/klayout:${TOOLS}/ngspice/lib:${TOOLS}/iverilog/lib:${TOOLS}/openems/lib:${TOOLS}/kactus2:${TOOLS}/gtkwave/lib/$(uname -m)-linux-gnu:${TOOLS}/kepler-formal/lib" && export LD_LIBRARY_PATH
    export EDITOR="gedit"
    export PYTHONPYCACHEPREFIX="/tmp/pycache"
    export KLAYOUT_HOME="/headless/.klayout"
    export SHELL=/bin/bash

    # Enable ngspice co-simulation with VHDL
    export CPATH="${TOOLS}/ghdl/include:${TOOLS}/ghdl/include/ghdl:${CPATH}"
    export LIBRARY_PATH="${TOOLS}/ghdl/lib:${LIBRARY_PATH}"

    # Default PDK — only set when not already provided by the user/sub-shell.
    export PDK=${PDK:-ihp-sg13g2}
    export PDKPATH=${PDKPATH:-$PDK_ROOT/$PDK}
    export STD_CELL_LIBRARY=${STD_CELL_LIBRARY:-sg13g2_stdcell}
    export SPICE_USERINIT_DIR=${SPICE_USERINIT_DIR:-$PDK_ROOT/$PDK/libs.tech/ngspice}
    export KLAYOUT_PATH=${KLAYOUT_PATH:-"/headless/.klayout:$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech"}

    # This gets rid of the DBUS warning
    # https://unix.stackexchange.com/questions/230238/x-applications-warn-couldnt-connect-to-accessibility-bus-on-stderr/230442#230442
    export NO_AT_BRIDGE=1

    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Final PATH variable: $PATH"
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Final PYTHONPATH variable: $PYTHONPATH"

    export FOSS_INIT_DONE=1
fi

# Ensure USER is set — gdsfactory's pydantic-settings reads it at startup.
# When the container is run with a numeric UID (--user UID:GID) without a matching
# /etc/passwd entry, the shell may not populate USER automatically.
[ -z "${USER}" ] && USER=$(id -un 2>/dev/null || echo designer) && export USER

# First, check if XDG_RUNTIME_DIR is set, if not, set to default.
if [ -z "${XDG_RUNTIME_DIR+x}" ]; then
    export XDG_RUNTIME_DIR=/tmp/runtime-default
fi
# Second, verify if the actual directory exists, if not, create it.
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# This is needed for Veryl to store its data
if [ -z "${XDG_DATA_HOME+x}" ]; then
    export XDG_DATA_HOME=/headless/.data-default
fi
if [ ! -d "$XDG_DATA_HOME" ]; then
    mkdir -p "$XDG_DATA_HOME"
fi

#----------------------------------------
# Source user configs from $DESIGNS
#----------------------------------------

if [ -n "${DESIGNS}" ] && [ -f "$DESIGNS/.designinit" ]; then
    # shellcheck source=/dev/null
    source "$DESIGNS/.designinit"
fi
