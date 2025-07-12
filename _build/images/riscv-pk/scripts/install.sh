#!/bin/bash
set -e
cd /tmp || exit 1

export PATH="$RISCV/bin:$PATH"

git clone --filter=blob:none "${RISCV_PK_REPO_URL}" "${RISCV_PK_NAME}"
cd "${RISCV_PK_NAME}" || exit 1
git checkout "${RISCV_PK_REPO_COMMIT}"
mkdir build && cd build
../configure --prefix="$RISCV" --host=riscv64-unknown-elf --with-arch=rv64gc_zifencei
make -j"$(nproc)"
make install
# and we strip the binaries to reduce size
find "$RISCV" -type f -executable -exec strip {} \;
