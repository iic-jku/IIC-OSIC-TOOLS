#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GHDL_REPO_URL}" "${GHDL_NAME}"
cd "${GHDL_NAME}" || exit 1
git checkout "${GHDL_REPO_COMMIT}"

# LLVM compile (needs LLVM<15)
./configure  --with-llvm-config --prefix="${TOOLS}/${GHDL_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
