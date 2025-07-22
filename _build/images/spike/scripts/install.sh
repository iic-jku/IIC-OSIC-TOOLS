#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SPIKE_REPO_URL}" "${SPIKE_NAME}"
cd "${SPIKE_NAME}" || exit 1
git checkout "${SPIKE_REPO_COMMIT}"
mkdir build && cd build
../configure --prefix="${TOOLS}/${SPIKE_NAME}"
make -j"$(nproc)" \
  ASFLAGS="-Os -g0" \
  CFLAGS="-Os -g0" \
  CXXFLAGS="-Os -g0" \
  LDFLAGS="-Wl,-s"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${SPIKE_NAME}/bin/* .

