#!/bin/bash

set -e

# Installing the LEMON version from OpenROAD
LEMON_PREFIX="/usr/local"
LEMON_VERSION=1.3.1
echo "[INFO] Installing LEMON version $LEMON_VERSION into $LEMON_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "${LEMON_VERSION}" https://github.com/The-OpenROAD-Project/lemon-graph.git
cd lemon-graph || exit 1
cmake \
    -D CMAKE_INSTALL_PREFIX="${LEMON_PREFIX}" \
    -D LEMON_ENABLE_GLPK=NO \
    -D LEMON_ENABLE_COIN=NO \
    -D LEMON_ENABLE_ILOG=NO \
    -B build .
cmake --build build -j "$(nproc)" --target install
