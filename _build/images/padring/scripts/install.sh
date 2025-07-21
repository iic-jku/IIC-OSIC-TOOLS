#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${PADRING_REPO_URL}" "${PADRING_NAME}"
cd "${PADRING_NAME}" || exit 1
git checkout "${PADRING_REPO_COMMIT}"
bash ./bootstrap.sh
cd build || exit 1
ninja
mkdir -p "${TOOLS}/${PADRING_NAME}/bin"
cp padring "${TOOLS}/${PADRING_NAME}/bin"

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

