#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"
#FIXME git submodule update --init --recursive
mkdir build && cd build
../configure --enable-multilib --with-sim=spike --prefix="${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" 
# these make flags remove the debug symbols
make ASFLAGS=g0 CFLAGS=-g0 CXXFLAGS=-g0 -j"$(nproc)" 
# and we strip the binaries to reduce size
find "${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME/bin" -type f -executable -exec strip {} \;
