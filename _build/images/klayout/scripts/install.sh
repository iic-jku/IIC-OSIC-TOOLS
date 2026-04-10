#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${KLAYOUT_REPO_URL}" "${KLAYOUT_NAME}"
cd "${KLAYOUT_NAME}" || exit 1
git checkout "${KLAYOUT_REPO_COMMIT}"
prefix=${TOOLS}/${KLAYOUT_NAME}
mkdir -p "$prefix"
#./build.sh -j"$(nproc)" -prefix "$prefix" -without-qtbinding
# we add the Qt-bindings again as it is needed for DRC and LVS, see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/111
./build.sh -qmake qmake6 -j "$(nproc)" -prefix "$prefix"

echo "${KLAYOUT_NAME} ${KLAYOUT_REPO_COMMIT}" > "${TOOLS}/${KLAYOUT_NAME}/SOURCES"
