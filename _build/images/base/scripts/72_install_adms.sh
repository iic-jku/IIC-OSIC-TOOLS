#!/bin/bash

set -e

# Need to compile ADMS manually, as version available via APT is outdated
# ADMS is currently only used by Xyce to compile Verilog-A models

cd /tmp
git clone --depth=1 https://github.com/Qucs/ADMS.git adms
cd adms || exit 1
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=/usr/local
make install
