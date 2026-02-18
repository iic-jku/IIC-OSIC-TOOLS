#!/bin/bash
set -e
cd /tmp || exit 1

# OpenROAD needs spdlog 1.8.1, so we update it here
SPDLOG_PREFIX="/usr/local"
SPDLOG_VERSION=1.8.1
echo "[INFO] Installing SPDLOG version $SPDLOG_VERSION into $SPDLOG_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "v${SPDLOG_VERSION}" https://github.com/gabime/spdlog.git
cd spdlog || exit 1
cmake -DCMAKE_INSTALL_PREFIX="${SPDLOG_PREFIX}" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPDLOG_BUILD_EXAMPLE=OFF -B build .
cmake --build build -j "$(nproc)" --target install

# --------------------------------------------------------------

git clone --filter=blob:none "${OPENROAD_LL_REPO_URL}" "${OPENROAD_LL_NAME}"
cd "${OPENROAD_LL_NAME}" || exit 1
git checkout "${OPENROAD_LL_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${OPENROAD_LL_NAME}" \
    -DUSE_SYSTEM_BOOST=ON \
    -DENABLE_TESTS=OFF \
    -DGTest_ROOT=/usr/local \
    -DBUILD_GUI=ON
make -j"$(nproc)"
make install
