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
# -include stdlib.h: since glibc 2.42 stdlib.h declares once_flag and call_once
# (ISO C23/C2Y, enabled by _GNU_SOURCE whatever -std says). The tinycthread copy
# bundled in SCIP 10.0.0 defines once_flag and call_once as macros, and the later
# stdlib.h include then fails with conflicting types for pthread_once_t. Pulling
# stdlib.h in first makes the macros come after the declarations. Drop this once
# SCIP's tinycthread handles it.
cmake -B build . \
    -DCMAKE_INSTALL_PREFIX=/opt/or-tools \
    -DBUILD_DEPS:BOOL=ON \
    -DBUILD_EXAMPLES:BOOL=OFF \
    -DBUILD_SAMPLES:BOOL=OFF \
    -DBUILD_TESTING:BOOL=OFF \
    -DCMAKE_CXX_FLAGS="-w" \
    -DCMAKE_C_FLAGS="-w -include stdlib.h"
cmake --build build --config Release -j "$(nproc)" --target install

# Remove Boost artifacts installed by OR-Tools (static-only Boost 1.87)
# to prevent conflicts with the system Boost 1.90.
# OR-Tools statically links Boost, so these are not needed at build/runtime.
echo "[INFO] Removing OR-Tools Boost artifacts to avoid version conflicts"
rm -rf /opt/or-tools/lib/cmake/Boost-* /opt/or-tools/lib/cmake/boost_*
rm -rf /opt/or-tools/include/boost
rm -rf /opt/or-tools/lib/libboost_*

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
