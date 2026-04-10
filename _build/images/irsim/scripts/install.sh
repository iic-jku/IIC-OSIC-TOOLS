#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${IRSIM_REPO_URL}" "${IRSIM_NAME}"
cd "${IRSIM_NAME}" || exit 1
git checkout "${IRSIM_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${IRSIM_NAME}"
make -j"$(nproc)"
make install

echo "${IRSIM_NAME} ${IRSIM_REPO_COMMIT}" > "${TOOLS}/${IRSIM_NAME}/SOURCES"
