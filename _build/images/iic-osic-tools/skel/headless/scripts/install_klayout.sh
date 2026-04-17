#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

# Add essential plugins to KLayout: plugin-utils, align-tool, move-tool, layer-shortcuts, klayout-auto-backup, klayout-pin-tool
git clone --depth=1 https://github.com/iic-jku/klayout-plugin-utils.git /headless/.klayout/salt/KLayoutPluginUtils
git clone --depth=1 https://github.com/iic-jku/klayout-align-tool.git /headless/.klayout/salt/AlignToolPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-move-tool.git /headless/.klayout/salt/MoveQuicklyToolPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-layer-shortcuts.git /headless/.klayout/salt/LayerShortcutsPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-auto-backup.git /headless/.klayout/salt/AutoBackupPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-pin-tool.git /headless/.klayout/salt/PinToolPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-library-manager.git /headless/.klayout/salt/LibraryManagerPlugin
git clone --depth=1 https://github.com/iic-jku/klayout-vector-file-export.git /headless/.klayout/salt/VectorFileExportPlugin
