#!/bin/bash

set -e

# Install or-tools (dependency of OpenROAD)
ORTOOLS_VERSION=9.6
echo "[INFO] Installing ORTOOLS version $ORTOOLS_VERSION"
cd /tmp || exit 1
wget --no-verbose "https://github.com/google/or-tools/archive/refs/tags/v$ORTOOLS_VERSION.tar.gz"
tar -xf "v$ORTOOLS_VERSION.tar.gz"
cd "or-tools-$ORTOOLS_VERSION" || exit 1
cmake -B build . -DBUILD_DEPS:BOOL=OFF -DBUILD_SCIP:BOOL=ON -DBUILD_CoinUtils:BOOL=ON -DBUILD_Osi:BOOL=ON -DBUILD_Clp:BOOL=ON -DBUILD_Cgl:BOOL=ON -DBUILD_Cbc:BOOL=ON -DBUILD_absl:BOOL=ON -DBUILD_Protobuf:BOOL=ON
cmake --build build -j "$(nproc)" --target install

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
