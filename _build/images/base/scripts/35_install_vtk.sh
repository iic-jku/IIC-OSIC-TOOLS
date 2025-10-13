#!/bin/bash

set -e

# Install VTK
VTK_VERSION=1.8.1
echo "[INFO] Installing VTK version $VTK_VERSION"
cd /tmp || exit 1
git clone --depth=1 https://gitlab.kitware.com/vtk/vtk.git
cd vtk || exit 1
git checkout "v${VTK_VERSION}"
mkdir -p build
cd build || exit 1
cmake ..
cmake --build ../build -j "$(nproc)"
rm -rf /tmp/*
