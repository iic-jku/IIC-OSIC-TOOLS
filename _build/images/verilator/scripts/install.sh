#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${VERILATOR_REPO_URL}" "${VERILATOR_NAME}"
cd "${VERILATOR_NAME}" || exit 1
git checkout "${VERILATOR_REPO_COMMIT}"
autoconf
unset VERILATOR_ROOT
./configure --prefix="${TOOLS}/${VERILATOR_NAME}"
make -j"$(nproc)"
make install
# and we strip the binaries to reduce size
find "${TOOLS}/${VERILATOR_NAME}" -type f -executable -exec strip {} \;
