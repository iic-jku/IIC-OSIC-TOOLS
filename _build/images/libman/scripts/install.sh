#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1 

git clone --filter=blob:none "${LIBMAN_REPO_URL}" "${LIBMAN_NAME}"
cd "${LIBMAN_NAME}" || exit 1
git checkout "${LIBMAN_REPO_COMMIT}"
mkdir -p build
cd build || exit 1
qmake6 ../libman.pro
export CAPNP_SKIP_CHECK=1
make -j1 capnp_install
make -j1 lstream_schemas
unset CAPNP_SKIP_CHECK
make -j"$(nproc)"
mkdir -p "${TOOLS}/${LIBMAN_NAME}/bin"
# binary may be named libman or LibMan depending on Qt version
binary=""
for p in libman LibMan release/libman release/LibMan; do
    if [ -f "$p" ]; then
        binary="$p"
        break
    fi
done
if [ -z "$binary" ]; then
    echo "ERROR: libman binary not found after build" >&2
    ls -la
    exit 1
fi
mv "$binary" "${TOOLS}/${LIBMAN_NAME}/bin/libman"

echo "${LIBMAN_NAME} ${LIBMAN_REPO_COMMIT}" > "${TOOLS}/${LIBMAN_NAME}/SOURCES"
