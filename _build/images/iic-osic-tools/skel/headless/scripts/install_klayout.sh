#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

# Install KLayout packages using KLayout's built-in package manager (Salt).
# Based on the script from the ieee_chipathon branch:
# _build/chipathon-overlay/klayout_install_packages.sh

KLAYOUT_HOME=${KLAYOUT_HOME:-/headless/.klayout}
KLAYOUT_SALT=$KLAYOUT_HOME/salt

# Maximum number of retry attempts for package installation (1 per second)
MAX_INSTALL_RETRIES=15

# Find KLayout binary
KLAYOUT_BIN=$(command -v klayout)
if [[ -z $KLAYOUT_BIN ]]; then
    if [[ -x "$TOOLS/klayout/klayout" ]]; then
        KLAYOUT_BIN="$TOOLS/klayout/klayout"
    else
        echo "[ERROR] klayout binary not found (not on PATH and not at \$TOOLS/klayout/klayout)" >&2
        exit 1
    fi
fi

mkdir -p "$KLAYOUT_SALT"

# Add essential plugins to KLayout: plugin-utils, align-tool, move-tool, layer-shortcuts,
# klayout-auto-backup, klayout-pin-tool, library-manager, vector-file-export,
# klive, xsection
packages=(
    KLayoutPluginUtils
    AlignToolPlugin
    MoveQuicklyToolPlugin
    LayerShortcutsPlugin
    AutoBackupPlugin
    PinToolPlugin
    LibraryManagerPlugin
    VectorFileExportPlugin
    klive
    xsection
)

for package in "${packages[@]}"; do
    echo "[INFO] Installing KLayout package: $package"

    COUNTER=$MAX_INSTALL_RETRIES
    # Flags: -t (tech only), -ne (no editing), -rr (no recovery), -b (batch), -y (install package)
    # Make an initial install attempt, then retry up to MAX_INSTALL_RETRIES times with 1s delays
    until [[ -d "$KLAYOUT_SALT/$package" || $COUNTER -lt 0 ]]; do
        "$KLAYOUT_BIN" -t -ne -rr -b -y "$package"
        sleep 1
        ((COUNTER--))
    done

    if [[ ! -d "$KLAYOUT_SALT/$package" ]]; then
        echo "[ERROR] Failed to install KLayout package: $package" >&2
        exit 1
    fi
done
