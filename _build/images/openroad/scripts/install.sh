#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${OPENROAD_REPO_URL}" "${OPENROAD_NAME}"
cd "${OPENROAD_NAME}" || exit 1
git checkout "${OPENROAD_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${OPENROAD_NAME}" "-DUSE_SYSTEM_BOOST=ON" "-DGTest_ROOT=/usr/local"
make -j"$(nproc)"
make install

# --------------------------------------------------------------
# Build latest OpenROAD version (in addition to specified version)
# --------------------------------------------------------------
# New OpenROAD needs spdlog 1.15.1, so we update it here (packaged version is 1.8.1)
SPDLOG_PREFIX="/usr/local"
SPDLOG_VERSION=1.15.1
echo "[INFO] Installing SPDLOG version $SPDLOG_VERSION into $SPDLOG_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "v${SPDLOG_VERSION}" https://github.com/gabime/spdlog.git
cd spdlog || exit 1
cmake -DCMAKE_INSTALL_PREFIX="${SPDLOG_PREFIX}" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPDLOG_BUILD_EXAMPLE=OFF -B build .
cmake --build build -j "$(nproc)" --target install
# --------------------------------------------------------------
cd "/tmp/${OPENROAD_NAME}" || exit 1 && rm -rf build && mkdir -p build && cd build
git checkout -
git submodule update --init --recursive
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${OPENROAD_NAME}-latest" "-DUSE_SYSTEM_BOOST=ON" "-DGTest_ROOT=/usr/local"
make -j"$(nproc)"
make install

# Get ORFS GitHub hash that works with this OR version
ORFS_COMMIT=$(git ls-remote https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git | grep HEAD | cut -f 1)
echo "$ORFS_COMMIT" > "${TOOLS}/${OPENROAD_NAME}-latest/ORFS_COMMIT"
