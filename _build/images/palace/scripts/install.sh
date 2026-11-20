#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1
git clone --filter=blob:none --no-checkout "${PALACE_REPO_URL}" "${PALACE_NAME}"
cd "${PALACE_NAME}" || exit 1
git checkout "${PALACE_REPO_COMMIT}"
mkdir -p build && cd build
# The configure step downloads about 20 patches from github.com within
# seconds, and GitHub answers such bursts with HTTP 503 for up to a minute.
# Palace does not retry (cmake/PatchHelpers.cmake), so retry the configure:
# patches that already arrived are kept (hash check), only the rest is fetched.
# Can go when Palace retries the downloads or ships the patches in its repo.
CONFIGURE_TRIES=10
for i in $(seq 1 "${CONFIGURE_TRIES}"); do
    if cmake .. -DCMAKE_INSTALL_PREFIX="${TOOLS}/${PALACE_NAME}" -DCMAKE_BUILD_TYPE=Release; then
        break
    fi
    if [ "$i" -eq "${CONFIGURE_TRIES}" ]; then
        echo "[ERROR] Palace configure failed ${CONFIGURE_TRIES} times."
        exit 1
    fi
    echo "[WARNING] Palace configure failed (try $i of ${CONFIGURE_TRIES}), next try in 30 s."
    sleep 30
done
cmake --build . -- -j "$(nproc)"
cmake --install .

# Remove static link libraries (~200 MB, mfem/petsc/palace); the palace
# binary is fully linked and does not need them at runtime
find "${TOOLS}/${PALACE_NAME}" -type f -name "*.a" -delete

echo "${PALACE_NAME} ${PALACE_REPO_COMMIT}" > "${TOOLS}/${PALACE_NAME}/SOURCES"

# Install gds2palace wrapper scripts (run_palace, combine_snp, combine_extend_snp.py)
mkdir -p "${TOOLS}/${PALACE_NAME}/bin" "${TOOLS}/${PALACE_NAME}/lib"
install -m 755 /images/palace/scripts/run_palace   "${TOOLS}/${PALACE_NAME}/bin/run_palace"
install -m 755 /images/palace/scripts/combine_snp  "${TOOLS}/${PALACE_NAME}/bin/combine_snp"
install -m 644 /images/palace/scripts/combine_extend_snp.py "${TOOLS}/${PALACE_NAME}/lib/combine_extend_snp.py"
