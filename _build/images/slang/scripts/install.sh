#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SLANG_REPO_URL}" "${SLANG_NAME}"
cd "${SLANG_NAME}" || exit 1
git checkout "${SLANG_REPO_COMMIT}"
cmake -B build -DSLANG_INCLUDE_TESTS=OFF
cmake --build build -j"$(nproc)"
cmake --install build --strip --prefix="${TOOLS}/${SLANG_NAME}"

echo "${SLANG_NAME} ${SLANG_REPO_COMMIT}" > "${TOOLS}/${SLANG_NAME}/SOURCES"
