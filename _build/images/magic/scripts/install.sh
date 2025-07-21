#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${MAGIC_REPO_URL}" "${MAGIC_NAME}"
cd "${MAGIC_NAME}" || exit 1
git checkout "${MAGIC_REPO_COMMIT}"
./configure --prefix="${TOOLS}/${MAGIC_NAME}"
make database/database.h
make -j"$(nproc)"
make install

echo "$MAGIC_NAME $MAGIC_REPO_COMMIT" > "${TOOLS}/${MAGIC_NAME}/SOURCES"

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
