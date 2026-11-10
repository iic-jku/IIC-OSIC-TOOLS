#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${NETGEN_REPO_URL}" "${NETGEN_NAME}"
cd "${NETGEN_NAME}" || exit 1
git checkout "${NETGEN_REPO_COMMIT}"
# -std=gnu17: GCC 15 defaults to C23, where () declares a function without
# parameters. netgen relies on the old meaning. Drop it once upstream builds as C23.
./configure CFLAGS="-O2 -g -std=gnu17" --prefix="${TOOLS}/${NETGEN_NAME}"
make clean
make -j"$(nproc)"
make install
# netgen's make carries on past compile errors, so check that the Tcl module exists.
if [ ! -f "${TOOLS}/${NETGEN_NAME}/lib/netgen/tcl/tclnetgen.so" ]; then
    echo "[ERROR] tclnetgen.so was not built."
    exit 1
fi

echo "${NETGEN_NAME} ${NETGEN_REPO_COMMIT}" > "${TOOLS}/${NETGEN_NAME}/SOURCES"
