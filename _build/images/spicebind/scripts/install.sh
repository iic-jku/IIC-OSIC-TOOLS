#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SPICEBIND_REPO_URL}" "${SPICEBIND_NAME}"
cd "${SPICEBIND_NAME}"
git checkout "${SPICEBIND_REPO_COMMIT}"

mkdir build && cd build
cmake -DNGSPICE_ROOT="${TOOLS}/ngspice" ..
cmake --build .
cmake --install . --prefix "${TOOLS}"
