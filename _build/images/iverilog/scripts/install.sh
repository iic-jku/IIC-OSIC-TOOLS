#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${IVERILOG_REPO_URL}" "${IVERILOG_NAME}"
cd "${IVERILOG_NAME}" || exit 1
git checkout "${IVERILOG_REPO_COMMIT}"
chmod +x autoconf.sh
./autoconf.sh
./configure --prefix="${TOOLS}/${IVERILOG_NAME}" --enable-libvvp
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
