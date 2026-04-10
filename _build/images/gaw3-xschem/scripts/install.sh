#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GAW3_XSCHEM_REPO_URL}" "${GAW3_XSCHEM_NAME}"
cd "${GAW3_XSCHEM_NAME}" || exit 1
git checkout "${GAW3_XSCHEM_REPO_COMMIT}"
chmod +x configure
autoreconf -f -i
./configure --prefix="${TOOLS}/${GAW3_XSCHEM_NAME}"
make -j"$(nproc)"
make install

echo "${GAW3_XSCHEM_NAME} ${GAW3_XSCHEM_REPO_COMMIT}" > "${TOOLS}/${GAW3_XSCHEM_NAME}/SOURCES"
