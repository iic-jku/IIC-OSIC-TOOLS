#!/bin/bash
set -e
cd /tmp || exit 1

git clone --branch "${VACASK_REPO_COMMIT}" "${VACASK_REPO_URL}" "${VACASK_NAME}"
cd "${VACASK_NAME}" || exit 1
mkdir -p build && cd build
cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release -DOPENVAF_DIR=${TOOLS}/openvaf/bin
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

