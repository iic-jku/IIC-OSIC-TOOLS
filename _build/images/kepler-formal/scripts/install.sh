#!/bin/bash
set -e
cd /tmp || exit 1

git clone --recurse-submodules "${KEPLER_FORMAL_REPO_URL}" "${KEPLER_FORMAL_NAME}"
cd "${KEPLER_FORMAL_NAME}" || exit 1
git checkout "${KEPLER_FORMAL_REPO_COMMIT}"
mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${KEPLER_FORMAL_NAME}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=20
make -j"$(nproc)"
make install

echo "$KEPLER_FORMAL_NAME $KEPLER_FORMAL_REPO_COMMIT" > "${TOOLS}/${KEPLER_FORMAL_NAME}/SOURCES"
