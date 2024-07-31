#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${IRSIM_REPO_URL}" "${IRSIM_NAME}"
cd "${IRSIM_NAME}" || exit 1
git checkout "${IRSIM_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${IRSIM_NAME}"
make -j"$(nproc)"
make install
