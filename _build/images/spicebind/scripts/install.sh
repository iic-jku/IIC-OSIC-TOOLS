#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SPICEBIND_REPO_URL}" "${SPICEBIND_NAME}"
cd "${SPICEBIND_NAME}" || exit 1
git checkout "${SPICEBIND_REPO_COMMIT}"

mkdir build && cd build
cmake -DNGSPICE_ROOT="${TOOLS}/ngspice" ..
cmake --build . -j"$(nproc)"
cmake --install . --prefix "${TOOLS}"

mkdir -p "${TOOLS}/${SPICEBIND_NAME}"
echo "${SPICEBIND_NAME} ${SPICEBIND_REPO_COMMIT}" > "${TOOLS}/${SPICEBIND_NAME}/SOURCES"
