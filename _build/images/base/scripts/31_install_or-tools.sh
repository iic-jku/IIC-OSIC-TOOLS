#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Install or-tools (dependency of OpenROAD)
ORTOOLS_VERSION=9.14
echo "[INFO] Installing ORTOOLS version $ORTOOLS_VERSION"
cd /tmp || exit 1
wget --no-verbose "https://github.com/google/or-tools/archive/refs/tags/v$ORTOOLS_VERSION.tar.gz"
tar -xf "v$ORTOOLS_VERSION.tar.gz"
cd "or-tools-$ORTOOLS_VERSION" || exit 1
# -std=gnu17: GCC 15 defaults to C23, where glibc 2.42+ declares once_flag and
# call_once itself. The tinycthread copy bundled in SCIP (10.0.0) then redefines
# them (conflicting types for pthread_once_t). Drop this once SCIP's tinycthread
# handles C23.
cmake -B build . \
    -DCMAKE_INSTALL_PREFIX=/opt/or-tools \
    -DBUILD_DEPS:BOOL=ON \
    -DBUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SAMPLES:BOOL=OFF \
    -DBUILD_TESTING:BOOL=OFF \
    -DCMAKE_CXX_FLAGS="-w" \
    -DCMAKE_C_FLAGS="-w -std=gnu17"
cmake --build build --config Release -j "$(nproc)" --target install

# Remove Boost artifacts installed by OR-Tools (static-only Boost 1.87)
# to prevent conflicts with the system Boost 1.88.
# OR-Tools statically links Boost, so these are not needed at build/runtime.
echo "[INFO] Removing OR-Tools Boost artifacts to avoid version conflicts"
rm -rf /opt/or-tools/lib/cmake/Boost-* /opt/or-tools/lib/cmake/boost_*
rm -rf /opt/or-tools/include/boost
rm -rf /opt/or-tools/lib/libboost_*

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
