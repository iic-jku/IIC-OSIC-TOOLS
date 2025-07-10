#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"
mkdir build && cd build
../configure --enable-multilib --prefix="${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" 
# these make flags remove the debug symbols
make ASFLAGS=g0 CFLAGS=-g0 CXXFLAGS=-g0 -j"$(nproc)" 
# and we strip the binaries to reduce size
find "${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" -type f -executable -exec strip {} \;
