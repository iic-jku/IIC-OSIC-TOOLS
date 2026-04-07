#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${NETGEN_REPO_URL}" "${NETGEN_NAME}"
cd "${NETGEN_NAME}" || exit 1
git checkout "${NETGEN_REPO_COMMIT}"
./configure CFLAGS="-O2 -g" --prefix="${TOOLS}/${NETGEN_NAME}"
make clean
make -j"$(nproc)"
make install

echo "${NETGEN_NAME} ${NETGEN_REPO_COMMIT}" > "${TOOLS}/${NETGEN_NAME}/SOURCES"
