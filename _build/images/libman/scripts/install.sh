#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1 

git clone --filter=blob:none "${LIBMAN_REPO_URL}" "${LIBMAN_NAME}"
cd "${LIBMAN_NAME}" || exit 1
git checkout "${LIBMAN_REPO_COMMIT}"
qmake6 libman.pro
make -j"$(nproc)"
mkdir -p "${TOOLS}/${LIBMAN_NAME}/bin"
mv libman "${TOOLS}/${LIBMAN_NAME}/bin"

echo "${LIBMAN_NAME} ${LIBMAN_REPO_COMMIT}" > "${TOOLS}/${LIBMAN_NAME}/SOURCES"
