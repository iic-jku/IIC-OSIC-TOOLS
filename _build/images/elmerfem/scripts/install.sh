#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${ELMERFEM_URL}" "${ELMERFEM_NAME}"
cd "${ELMERFEM_NAME}" || exit 1
git checkout "${ELMERFEM_COMMIT}"
git submodule update --init --recursive

mkdir -p build && cd build
cmake .. "-DCMAKE_INSTALL_PREFIX=${TOOLS}/${ELMFERFEM_NAME}" -DWITH_MPI:BOOL=TRUE
make -j"$(nproc)"
make install
