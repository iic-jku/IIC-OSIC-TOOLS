#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

git clone --filter=blob:none --branch "${SURFER_REPO_COMMIT}" "${SURFER_REPO_URL}" "${SURFER_NAME}"
cd "${SURFER_NAME}" || exit 1
git submodule update --init --recursive
cargo build --release -j"$(nproc)"
strip target/release/surfer
strip target/release/surver
mkdir -p "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/surfer "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/surver "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/liblibsurfer.so "${TOOLS}/${SURFER_NAME}/bin"

# LD_PRELOAD shim: disable SysV SHM so Mesa's software renderer presents
# via core-protocol PutImage on remote X servers. XQuartz (macOS) advertises
# MIT-SHM, but attaching container SHM segments across the VM boundary fails
# on every frame and Mesa has no per-frame fallback -> blank window.
mkdir -p "${TOOLS}/${SURFER_NAME}/lib/noglx"
cat > /tmp/noshm.c << 'EOF'
#include <errno.h>
#include <sys/types.h>
int shmget(key_t key, size_t size, int shmflg) {
    (void)key; (void)size; (void)shmflg;
    errno = ENOSYS;
    return -1;
}
EOF
gcc -shared -fPIC -o "${TOOLS}/${SURFER_NAME}/lib/libnoshm.so" /tmp/noshm.c

# Empty libGL stubs: dlopen fails -> eframe/glutin falls back from GLX
# (unusable against XQuartz) to EGL (llvmpipe, OpenGL 4.5). Used by the
# surfer wrapper installed in install_links.sh.
# GLX half reported as https://gitlab.com/surfer-project/surfer/-/issues/211;
# the MIT-SHM half above is a Mesa/X limitation, not a Surfer defect.
touch "${TOOLS}/${SURFER_NAME}/lib/noglx/libGL.so.1" \
      "${TOOLS}/${SURFER_NAME}/lib/noglx/libGL.so"

echo "${SURFER_NAME} ${SURFER_REPO_COMMIT}" > "${TOOLS}/${SURFER_NAME}/SOURCES"
