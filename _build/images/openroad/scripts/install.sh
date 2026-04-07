#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

# OpenROAD needs SWIG >= 4.3, but Ubuntu 24.04 ships 4.2.0
SWIG_PREFIX="/usr/local"
SWIG_VERSION=4.3.0
echo "[INFO] Installing SWIG version $SWIG_VERSION into $SWIG_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "v${SWIG_VERSION}" https://github.com/swig/swig.git
cd swig || exit 1
./autogen.sh
./configure --prefix="${SWIG_PREFIX}"
make -j"$(nproc)"
make install

# OpenROAD needs spdlog 1.15.1, so we update it here (packaged version is 1.8.1 for openroad-librelane)
SPDLOG_PREFIX="/usr/local"
SPDLOG_VERSION=1.15.1
echo "[INFO] Installing SPDLOG version $SPDLOG_VERSION into $SPDLOG_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "v${SPDLOG_VERSION}" https://github.com/gabime/spdlog.git
cd spdlog || exit 1
cmake -DCMAKE_INSTALL_PREFIX="${SPDLOG_PREFIX}" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPDLOG_BUILD_EXAMPLE=OFF -B build .
cmake --build build -j "$(nproc)" --target install

# --------------------------------------------------------------

cd /tmp || exit 1
git clone --filter=blob:none "${OPENROAD_REPO_URL}" "${OPENROAD_NAME}"
cd "${OPENROAD_NAME}" || exit 1
git checkout "${OPENROAD_REPO_COMMIT}"
git submodule update --init --recursive
# Fix Tcl_Size compatibility: SWIG 4.2 generates Tcl_Size (Tcl 9.0) but we have Tcl 8.6.
# Patch system tcl.h so ALL compilation units see it (including SWIG-generated wrappers).
if ! grep -q 'Tcl_Size' /usr/include/tcl/tcl.h; then
    sed -i '/#define TCL_VERSION/a \\n#ifndef Tcl_Size\ntypedef int Tcl_Size;\n#endif' /usr/include/tcl/tcl.h
fi
mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${OPENROAD_NAME}" \
    -DSWIG_EXECUTABLE="${SWIG_PREFIX}/bin/swig" \
    -DUSE_SYSTEM_BOOST=ON \
    -DENABLE_TESTS=OFF \
    -DBUILD_GUI=ON
make -j"$(nproc)"
make install

# Get ORFS GitHub hash that works with this OR version
ORFS_COMMIT=$(git ls-remote https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git HEAD | cut -f 1)
echo "$ORFS_COMMIT" > "${TOOLS}/${OPENROAD_NAME}/ORFS_COMMIT"

echo "${OPENROAD_NAME} ${OPENROAD_REPO_COMMIT}" > "${TOOLS}/${OPENROAD_NAME}/SOURCES"
