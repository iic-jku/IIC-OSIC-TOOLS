#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${SURELOG_REPO_URL}" "${SURELOG_NAME}"
cd "${SURELOG_NAME}" || exit 1
git checkout "${SURELOG_REPO_COMMIT}"
git submodule update --init --recursive --filter=blob:none
# CMake 4 rejects cmake_minimum_required below 3.5 in the bundled capnproto. The environment
# variable also reaches the nested CMake runs. Drop it once upstream raises it.
export CMAKE_POLICY_VERSION_MINIMUM=3.5
make -j"$(nproc)"
make install PREFIX="${TOOLS}/${SURELOG_NAME}"

echo "${SURELOG_NAME} ${SURELOG_REPO_COMMIT}" > "${TOOLS}/${SURELOG_NAME}/SOURCES"
