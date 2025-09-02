#!/bin/bash
set -e

# Install or-tools (dependency of OpenROAD)
ORTOOLS_VERSION=9.11
echo "[INFO] Installing ORTOOLS version $ORTOOLS_VERSION"
cd /tmp || exit 1
wget --no-verbose "https://github.com/google/or-tools/archive/refs/tags/v$ORTOOLS_VERSION.tar.gz"
tar -xf "v$ORTOOLS_VERSION.tar.gz"
cd "or-tools-$ORTOOLS_VERSION" || exit 1
cmake -B build . \
    -DBUILD_DEPS:BOOL=ON \
    -DBUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SAMPLES:BOOL=OFF \
    -DBUILD_TESTING:BOOL=OFF \
    -DCMAKE_CXX_FLAGS="-w" \
    -DCMAKE_C_FLAGS="-w"
cmake --build build --config Release -j "$(nproc)" --target install

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
