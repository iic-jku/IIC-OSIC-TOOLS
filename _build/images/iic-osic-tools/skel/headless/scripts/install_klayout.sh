#!/bin/bash

# Add essential plugins to klayout: align-tool, move-tool, layer-shortcuts, klayout-auto-backup
git clone --depth=1 https://github.com/iic-jku/klayout-align-tool.git /headless/.klayout/salt/klayout-align-tool
git clone --depth=1 https://github.com/iic-jku/klayout-move-tool.git /headless/.klayout/salt/klayout-move-tool
git clone --depth=1 https://github.com/iic-jku/klayout-layer-shortcuts.git /headless/.klayout/salt/klayout-layer-shortcuts
git clone --depth=1 https://github.com/iic-jku/klayout-auto-backup.git /headless/.klayout/salt/klayout-auto-backup
