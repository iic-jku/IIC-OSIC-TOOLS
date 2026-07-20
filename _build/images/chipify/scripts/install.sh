#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${CHIPIFY_REPO_URL}" "${CHIPIFY_NAME}"
cd "${CHIPIFY_NAME}" || exit 1
git checkout "${CHIPIFY_REPO_COMMIT}"

pip3 install . --prefix="${TOOLS}/${CHIPIFY_NAME}" --no-cache-dir

# Create bin symlink so install_links.sh can find the executables
ln -s "${TOOLS}/${CHIPIFY_NAME}/local/bin" "${TOOLS}/${CHIPIFY_NAME}/bin"

# Remove clone to save space in final image
cd /tmp && rm -rf "${CHIPIFY_NAME}"

echo "${CHIPIFY_NAME} ${CHIPIFY_REPO_COMMIT}" > "${TOOLS}/${CHIPIFY_NAME}/SOURCES"
