#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${NVC_REPO_URL}" "${NVC_NAME}"
cd "${NVC_NAME}" || exit 1
git checkout "${NVC_REPO_COMMIT}"
./autogen.sh
mkdir build && cd build
../configure --prefix="${TOOLS}/${NVC_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${NVC_NAME}/bin/* .

