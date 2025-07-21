#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XCIRCUIT_REPO_URL}" "${XCIRCUIT_NAME}"
cd "${XCIRCUIT_NAME}" || exit 1
git checkout "${XCIRCUIT_REPO_COMMIT}"
aclocal && automake && autoconf
./configure --prefix="${TOOLS}/${XCIRCUIT_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

