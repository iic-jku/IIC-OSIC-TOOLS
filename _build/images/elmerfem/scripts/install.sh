#!/bin/bash

set -e

REPO_COMMIT_SHORT=$(echo "$ELMERFEM_REPO_COMMIT" | cut -c 1-7)

git clone --filter=blob:none "${ELMERFEM_URL}" "${ELMERFEM_NAME}"
cd "${ELMERFEM_NAME}"
git checkout "${ELMERFEM_COMMIT}"
git submodule update --init --recursive

mkdir -p build && cd build
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${ELMFERFEM_NAME}/${REPO_COMMIT_SHORT}" -DWITH_MPI:BOOL=TRUE
make -j"$(nproc)"
make install
