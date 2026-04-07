#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${KACTUS_REPO_URL}" "${KACTUS_NAME}"
cd "${KACTUS_NAME}" || exit 1
git checkout "${KACTUS_REPO_COMMIT}"
sed -i "s|^LOCAL_INSTALL_DIR=\".*\"|LOCAL_INSTALL_DIR=\"${TOOLS}/${KACTUS_NAME}\"|" .qmake.conf
./configure
make -j"$(nproc)"
make install

echo "${KACTUS_NAME} ${KACTUS_REPO_COMMIT}" > "${TOOLS}/${KACTUS_NAME}/SOURCES"
