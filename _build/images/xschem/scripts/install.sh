#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XSCHEM_REPO_URL}" "${XSCHEM_NAME}"
cd "${XSCHEM_NAME}" || exit 1
git checkout "${XSCHEM_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${XSCHEM_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${XSCHEM_NAME}/*/bin/* .

