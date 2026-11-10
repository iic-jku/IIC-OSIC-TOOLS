#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${GHDL_REPO_URL}" "${GHDL_NAME}"
cd "${GHDL_NAME}" || exit 1
git checkout "${GHDL_REPO_COMMIT}"

# LLVM backend, built against the llvm-config of base-dev. clang-18 would pick
# the newest GCC installation (16, present through gfortran), whose libstdc++
# headers it cannot parse. --gcc-install-dir pins it to the default g++.
GCC_INSTALL_DIR=$(dirname "$(gcc -print-libgcc-file-name)")
CXX="clang++ --gcc-install-dir=${GCC_INSTALL_DIR}" ./configure  --with-llvm-config --prefix="${TOOLS}/${GHDL_NAME}"
make -j"$(nproc)"
make install

echo "${GHDL_NAME} ${GHDL_REPO_COMMIT}" > "${TOOLS}/${GHDL_NAME}/SOURCES"
