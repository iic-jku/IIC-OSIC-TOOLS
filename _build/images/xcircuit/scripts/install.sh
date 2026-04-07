#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XCIRCUIT_REPO_URL}" "${XCIRCUIT_NAME}"
cd "${XCIRCUIT_NAME}" || exit 1
git checkout "${XCIRCUIT_REPO_COMMIT}"
aclocal && automake && autoconf
./configure --prefix="${TOOLS}/${XCIRCUIT_NAME}"
make -j"$(nproc)"
make install

echo "${XCIRCUIT_NAME} ${XCIRCUIT_REPO_COMMIT}" > "${TOOLS}/${XCIRCUIT_NAME}/SOURCES"
