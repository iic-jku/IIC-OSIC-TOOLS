#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${OPENROAD_APP_REPO_URL}" "${OPENROAD_APP_NAME}"
cd "${OPENROAD_APP_NAME}" || exit 1
git checkout "${OPENROAD_APP_REPO_COMMIT}"
git submodule update --init --recursive

mkdir -p build && cd build
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${OPENROAD_APP_NAME}" "-DUSE_SYSTEM_BOOST=ON"
make -j"$(nproc)"
make install
