#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${IRSIM_REPO_URL}" "${IRSIM_NAME}"
cd "${IRSIM_NAME}" || exit 1
git checkout "${IRSIM_REPO_COMMIT}"
# -std=gnu17: GCC 15 defaults to C23, where () declares a function without
# parameters and bool, true and false are keywords. The sources rely on the old
# meaning. Drop it once upstream builds as C23.
CFLAGS="-O2 -std=gnu17" ./configure --prefix="${TOOLS}/${IRSIM_NAME}"
make -j"$(nproc)"
make install

echo "${IRSIM_NAME} ${IRSIM_REPO_COMMIT}" > "${TOOLS}/${IRSIM_NAME}/SOURCES"
