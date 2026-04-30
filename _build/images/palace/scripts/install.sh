#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1
git clone --filter=blob:none "${PALACE_REPO_URL}" "${PALACE_NAME}"
cd "${PALACE_NAME}" || exit 1
git checkout "${PALACE_REPO_COMMIT}"
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="${TOOLS}/${PALACE_NAME}" -DCMAKE_BUILD_TYPE=Release
cmake --build . -- -j "$(nproc)"
cmake --install .

echo "${PALACE_NAME} ${PALACE_REPO_COMMIT}" > "${TOOLS}/${PALACE_NAME}/SOURCES"

# Install gds2palace wrapper scripts (run_palace, combine_snp, combine_extend_snp.py)
mkdir -p "${TOOLS}/${PALACE_NAME}/bin" "${TOOLS}/${PALACE_NAME}/lib"
install -m 755 /images/palace/scripts/run_palace   "${TOOLS}/${PALACE_NAME}/bin/run_palace"
install -m 755 /images/palace/scripts/combine_snp  "${TOOLS}/${PALACE_NAME}/bin/combine_snp"
install -m 644 /images/palace/scripts/combine_extend_snp.py "${TOOLS}/${PALACE_NAME}/lib/combine_extend_snp.py"
