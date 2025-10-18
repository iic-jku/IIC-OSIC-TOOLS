#!/bin/bash
set -e
cd /tmp || exit 1
git clone --filter=blob:none "${PALACE_REPO_URL}" "${PALACE_NAME}"
cd "${PALACE_NAME}" || exit 1
git checkout "${PALACE_REPO_COMMIT}"
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="${TOOLS}/${PALACE_NAME}" -DCMAKE_BUILD_TYPE=Release
cmake --build . -- -j "$(nproc)"
