#!/bin/bash
set -e
cd /tmp || exit 1

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
