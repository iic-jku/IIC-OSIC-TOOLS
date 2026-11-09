#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${KLAYOUT_REPO_URL}" "${KLAYOUT_NAME}"
cd "${KLAYOUT_NAME}" || exit 1
git checkout "${KLAYOUT_REPO_COMMIT}"

# KLayout 0.30.13 generates its Qt6 bindings from the Qt 6.6.1 headers (upstream commit 27f830b8), and they do
# not compile with the Qt 6.4.2 of Ubuntu 24.04. Use the generated bindings of 0.30.12, which nothing else in
# the source tree depends on. Remove once the base image has Qt >= 6.6.
git restore --source=v0.30.12 --worktree -- src/gsiqt/qt6

prefix=${TOOLS}/${KLAYOUT_NAME}
mkdir -p "$prefix"
#./build.sh -j"$(nproc)" -prefix "$prefix" -without-qtbinding
# we add the Qt-bindings again as it is needed for DRC and LVS, see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/111
./build.sh -qmake qmake6 -j "$(nproc)" -prefix "$prefix"

echo "${KLAYOUT_NAME} ${KLAYOUT_REPO_COMMIT}" > "${TOOLS}/${KLAYOUT_NAME}/SOURCES"
