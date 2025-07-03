#!/bin/bash
set -e

cd /tmp || exit 1
git clone --filter=blob:none "${KACTUS_REPO_URL}" "${KACTUS_NAME}"
cd "${KACTUS_NAME}" || exit 1
git checkout "${KACTUS_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${KACTUS_NAME}"
make -j"$(nproc)"
make install
