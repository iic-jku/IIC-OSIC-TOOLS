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

# Build latest OpenROAD version (in addition to specified version)
cd .. && rm -rf build && mkdir -p build && cd build
git checkout -
git submodule update --init --recursive
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${OPENROAD_NAME}-latest" "-DUSE_SYSTEM_BOOST=ON" "-DGTest_ROOT=/usr/local"
make -j"$(nproc)"
make install

# Get ORFS GitHub hash that works with this OR version
ORFS_COMMIT=$(git ls-remote https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git | grep HEAD | cut -f 1)
echo "$ORFS_COMMIT" > "${TOOLS}/${OPENROAD_NAME}-latest/ORFS_COMMIT"

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${OPENROAD_NAME}/bin/* .
