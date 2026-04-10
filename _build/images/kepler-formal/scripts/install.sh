#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${KEPLER_FORMAL_REPO_URL}" "${KEPLER_FORMAL_NAME}"
cd "${KEPLER_FORMAL_NAME}" || exit 1
git checkout "${KEPLER_FORMAL_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${KEPLER_FORMAL_NAME}" \
    -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
make install

echo "${KEPLER_FORMAL_NAME} ${KEPLER_FORMAL_REPO_COMMIT}" > "${TOOLS}/${KEPLER_FORMAL_NAME}/SOURCES"
