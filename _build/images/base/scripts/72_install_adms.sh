#!/bin/bash

set -e

# Need to compile ADMS manually, as version available via APT is outdated
# ADMS is currently only used by Xyce to compile Verilog-A models

echo "[INFO] Installing ADMS"
cd /tmp || exit 1
git clone --depth=1 https://github.com/Qucs/ADMS.git adms
cd adms || exit 1
cmake -B build -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build -j "$(nproc)" --target install

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
