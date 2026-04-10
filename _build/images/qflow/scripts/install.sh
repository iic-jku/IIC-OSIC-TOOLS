#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${QFLOW_REPO_URL}" "${QFLOW_NAME}"
cd "${QFLOW_NAME}" || exit 1
git checkout "${QFLOW_REPO_COMMIT}"
./configure
cd src || exit 1
make vlog2Verilog && make vlog2Spice
mkdir -p "${TOOLS}/${QFLOW_NAME}/bin"
cp vlog2Verilog "${TOOLS}/${QFLOW_NAME}/bin"
cp vlog2Spice "${TOOLS}/${QFLOW_NAME}/bin"
cd ../scripts || exit 1
make spi2xspice.py
chmod +x spi2xspice.py
cp spi2xspice.py "${TOOLS}/${QFLOW_NAME}/bin"

echo "${QFLOW_NAME} ${QFLOW_REPO_COMMIT}" > "${TOOLS}/${QFLOW_NAME}/SOURCES"
