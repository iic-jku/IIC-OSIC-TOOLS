#!/bin/bash

set -e

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

####################
# INSTALL ICPS PDK
####################

echo "[INFO] Installing ICPS PDK."

git clone --filter=blob:none "${ANAGIXLOADER_REPO_URL}" $PDK_ROOT/icps/AnagixLoader
cd $PDK_ROOT/icps/AnagixLoader
git checkout "${ANAGIXLOADER_REPO_COMMIT}"

git clone --filter=blob:none "${ICPS_REPO_URL}" $PDK_ROOT/icps/ICPS2023_5
cd $PDK_ROOT/icps/ICPS2023_5
git checkout "${ICPS_REPO_COMMIT}"

# Create symlink to KLayout salt directory
mkdir -p /headless/.klayout/salt/
ln -s $PDK_ROOT/icps/AnagixLoader /headless/.klayout/salt/AnagixLoader
ln -s $PDK_ROOT/icps/ICPS2023_5 /headless/.klayout/salt/ICPS2023_5
