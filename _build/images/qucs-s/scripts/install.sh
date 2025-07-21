#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$QUCS_S_REPO_URL" "$QUCS_S_NAME"
cd "$QUCS_S_NAME" || exit 1
git checkout "$QUCS_S_REPO_COMMIT"
mkdir build && cd build
cmake ..  -DCMAKE_INSTALL_PREFIX="$TOOLS/$QUCS_S_NAME"
make -j"$(nproc)"
make install

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

