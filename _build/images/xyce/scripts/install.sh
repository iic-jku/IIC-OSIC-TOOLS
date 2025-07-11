#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XYCE_REPO_URL}" "${XYCE_NAME}"
cd "${XYCE_NAME}" || exit 1
git checkout "${XYCE_REPO_COMMIT}"
./bootstrap

git clone --filter=blob:none "${XYCE_TRILINOS_REPO_URL}" "${XYCE_TRILINOS_NAME}"
cd "${XYCE_TRILINOS_NAME}" || exit 1
git checkout "${XYCE_TRILINOS_REPO_COMMIT}"
mkdir -p parallel_build && cd parallel_build
cp /images/xyce/scripts/trilinos.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh
make -j"$(nproc)"
make install

cd /tmp/"${XYCE_NAME}" || exit 1
mkdir -p parallel_build && cd parallel_build
cp /images/xyce/scripts/xyce.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh

# build models
cd src/DeviceModelPKG/ADMS
make -j"$(nproc)"
cd ../../..

# build Xyce
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
# Add link for xyce, as binary is named Xyce
ln -s Xyce xyce
