#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "$RISCV_GNU_TOOLCHAIN_REPO_URL" "$RISCV_GNU_TOOLCHAIN_NAME"
cd "$RISCV_GNU_TOOLCHAIN_NAME" || exit 1
git checkout "$RISCV_GNU_TOOLCHAIN_REPO_COMMIT"
#FIXME WA according to https://github.com/riscv-collab/riscv-gnu-toolchain/issues/1669
sed -i '/shallow = true/d' .gitmodules
sed -i 's/--depth 1//g' Makefile.in

#git submodule update --init --recursive
mkdir build && cd build
../configure --prefix="${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME" --enable-multilib --with-sim=spike
make ASFLAGS=g0 CFLAGS=-g0 CXXFLAGS=-g0 -j"$(nproc)" 

find "${TOOLS}/$RISCV_GNU_TOOLCHAIN_NAME/bin" -type f -executable -exec strip {} \;
