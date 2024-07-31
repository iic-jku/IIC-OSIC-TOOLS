#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"
#git submodule update --init --recursive
mkdir build && cd build
../configure --enable-multilib --prefix="${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME"
make linux -j"$(nproc)"
