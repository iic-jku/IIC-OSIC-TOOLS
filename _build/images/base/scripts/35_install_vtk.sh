#!/bin/bash

set -e

# Install VTK
VTK_VERSION=9.1.0
echo "[INFO] Installing VTK version $VTK_VERSION"
cd /tmp || exit 1
git clone --depth=1 https://gitlab.kitware.com/vtk/vtk.git
cd vtk || exit 1
git checkout "v${VTK_VERSION}"
mkdir -p build
cd build || exit 1
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DVTK_GROUP_ENABLE_Qt=YES \
    -DVTK_MODULE_ENABLE_VTK_GUISupportQt=YES \
    -DVTK_MODULE_ENABLE_VTK_ViewsQt=YES \
    -DVTK_QT_VERSION=6 \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_SHARED_LIBS=ON
cmake --build . -j "$(nproc)"
cmake --install .
rm -rf /tmp/*
