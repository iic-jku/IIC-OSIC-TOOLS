#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${COVERED_REPO_URL}" "${COVERED_NAME}"
cd "${COVERED_NAME}" || exit 1
git checkout "${COVERED_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${COVERED_NAME}"
make # -j$(nproc) Using the -j option leads to random fails on many-core machines
make install
