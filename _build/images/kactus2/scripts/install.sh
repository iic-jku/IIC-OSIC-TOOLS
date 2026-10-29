#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${KACTUS2_REPO_URL}" "${KACTUS2_NAME}"
cd "${KACTUS2_NAME}" || exit 1
git checkout "${KACTUS2_REPO_COMMIT}"
sed -i "s|^LOCAL_INSTALL_DIR=\".*\"|LOCAL_INSTALL_DIR=\"${TOOLS}/${KACTUS2_NAME}\"|" .qmake.conf
./configure
make -j"$(nproc)"
make install

echo "${KACTUS2_NAME} ${KACTUS2_REPO_COMMIT}" > "${TOOLS}/${KACTUS2_NAME}/SOURCES"
