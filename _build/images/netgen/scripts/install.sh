#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${NETGEN_REPO_URL}" "${NETGEN_NAME}"
cd "${NETGEN_NAME}" || exit 1
git checkout "${NETGEN_REPO_COMMIT}"
./configure CFLAGS="-O2 -g" --prefix="${TOOLS}/${NETGEN_NAME}"
make clean
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
