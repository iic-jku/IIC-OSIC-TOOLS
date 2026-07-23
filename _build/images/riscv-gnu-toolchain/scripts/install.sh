#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"

# sourceware.org's git server is overloaded and often returns HTTP 502 while
# make clones the binutils/gdb/newlib submodules; fetch them from actively
# synced read-only GitHub mirrors instead
git config --global url."https://github.com/gnutools/binutils-gdb.git".insteadOf "https://sourceware.org/git/binutils-gdb.git"
git config --global url."https://github.com/RTEMS/sourceware-mirror-newlib-cygwin.git".insteadOf "https://sourceware.org/git/newlib-cygwin.git"
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

echo "${RISCV_GNU_TOOLCHAIN_NAME} ${RISCV_GNU_TOOLCHAIN_REPO_COMMIT}" > "${TOOLS}/${RISCV_GNU_TOOLCHAIN_NAME}/SOURCES"
