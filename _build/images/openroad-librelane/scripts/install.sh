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

git clone --filter=blob:none "${OPENROAD_LIBRELANE_REPO_URL}" "${OPENROAD_LIBRELANE_NAME}"
cd "${OPENROAD_LIBRELANE_NAME}" || exit 1
git checkout "${OPENROAD_LIBRELANE_REPO_COMMIT}"
git submodule update --init --recursive
#FIXME We apply this patch to allow control of analog routes.
#FIXME https://github.com/FPGA-Research/heichips25-tapeout/blob/main/disable_auto_taper.patch
sed -i 's/bool AUTO_TAPER_NDR_NETS = true;/bool AUTO_TAPER_NDR_NETS = false;/' src/drt/src/global.h
mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${OPENROAD_LIBRELANE_NAME}" \
    -DUSE_SYSTEM_BOOST=ON \
    -DENABLE_TESTS=OFF \
    -DGTest_ROOT=/usr/local \
    -DBUILD_GUI=ON
make -j"$(nproc)"
make install

echo "${OPENROAD_LIBRELANE_NAME} ${OPENROAD_LIBRELANE_REPO_COMMIT}" > "${TOOLS}/${OPENROAD_LIBRELANE_NAME}/SOURCES"
