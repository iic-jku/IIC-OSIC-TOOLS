#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
set -u
cd /tmp || exit 1

git clone --filter=blob:none "${CVC_RV_REPO_URL}" "${CVC_RV_NAME}"
cd "${CVC_RV_NAME}" || exit 1
git checkout "${CVC_RV_REPO_COMMIT}"
autoreconf -vif
./configure --disable-nls --prefix="${TOOLS}/${CVC_RV_NAME}"

make -j"$(nproc)"
make install

echo "${CVC_RV_NAME} ${CVC_RV_REPO_COMMIT}" > "${TOOLS}/${CVC_RV_NAME}/SOURCES"
