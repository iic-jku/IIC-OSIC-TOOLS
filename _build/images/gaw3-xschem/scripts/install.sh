#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GAW3_XSCHEM_REPO_URL}" "${GAW3_XSCHEM_NAME}"
cd "${GAW3_XSCHEM_NAME}" || exit 1
git checkout "${GAW3_XSCHEM_REPO_COMMIT}"
chmod +x configure
autoreconf -f -i
./configure --prefix="${TOOLS}/${GAW3_XSCHEM_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${GAW3_XSCHEM_NAME}/bin/* .
