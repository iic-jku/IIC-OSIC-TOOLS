#!/bin/bash
set -e
cd /tmp || exit 1 

git clone --filter=blob:none "${LIBMAN_REPO_URL}" "${LIBMAN_NAME}"
cd "${LIBMAN_NAME}" || exit 1
git checkout "${LIBMAN_REPO_COMMIT}"
qmake libman.pro
make
mkdir -p "${TOOLS}/${LIBMAN_NAME}"
mv libman "${TOOLS}/${LIBMAN_NAME}"

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
