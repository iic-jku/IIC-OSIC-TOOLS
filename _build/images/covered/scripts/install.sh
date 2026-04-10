#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${COVERED_REPO_URL}" "${COVERED_NAME}"
cd "${COVERED_NAME}" || exit 1
git checkout "${COVERED_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${COVERED_NAME}"
make # -j$(nproc) Using the -j option leads to random fails on many-core machines
make install

echo "${COVERED_NAME} ${COVERED_REPO_COMMIT}" > "${TOOLS}/${COVERED_NAME}/SOURCES"
