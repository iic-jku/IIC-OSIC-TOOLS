#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SPIKE_REPO_URL}" "${SPIKE_NAME}"
cd "${SPIKE_NAME}" || exit 1
git checkout "${SPIKE_REPO_COMMIT}"
mkdir build && cd build
../configure --prefix="$RISCV"
make -j"$(nproc)"
make install
