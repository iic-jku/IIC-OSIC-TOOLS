#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"
mkdir build && cd build

../configure \
    --enable-multilib \
    --with-multilib-generator="rv64gc-lp64d--;rv32i-ilp32--;rv32e-ilp32e--;rv32imcb-ilp32--" \
    --prefix="${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" 

make \
    ASFLAGS="-Os -g0" \
    CFLAGS="-Os -g0" \
    CXXFLAGS="-Os -g0" \
    LDFLAGS="-Wl,-s" \
    -j"$(nproc)" 

# and we strip the binaries to reduce size
find "${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" -type f -executable -exec strip {} \;
