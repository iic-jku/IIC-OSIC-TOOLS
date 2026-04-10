#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SPIKE_REPO_URL}" "${SPIKE_NAME}"
cd "${SPIKE_NAME}" || exit 1
git checkout "${SPIKE_REPO_COMMIT}"
mkdir build && cd build
../configure --prefix="${TOOLS}/${SPIKE_NAME}"
make -j"$(nproc)" \
  ASFLAGS="-Os -g0" \
  CFLAGS="-Os -g0" \
  CXXFLAGS="-Os -g0" \
  LDFLAGS="-Wl,-s"
make install

export PATH="$RISCV/bin:$PATH"
cd /tmp || exit 1

git clone --filter=blob:none "${RISCV_PK_REPO_URL}" "riscv-pk"
cd "riscv-pk" || exit 1
git checkout "${RISCV_PK_REPO_COMMIT}"
mkdir build && cd build
../configure --prefix="${TOOLS}/${SPIKE_NAME}" --host=riscv64-unknown-elf --with-arch=rv64gc_zifencei
make -j"$(nproc)"
make install

echo "${SPIKE_NAME} ${SPIKE_REPO_COMMIT}" > "${TOOLS}/${SPIKE_NAME}/SOURCES"
echo "riscv-pk ${RISCV_PK_REPO_COMMIT}" >> "${TOOLS}/${SPIKE_NAME}/SOURCES"
