#!/bin/bash
set -e

apt-get install -y clang-16 \
        clang-tools-16 \
        libclang-common-16-dev \
        libpolly-16-dev \
        lld-16 \
        llvm-16 \
        llvm-16-dev

cd /usr/lib/llvm-16/bin
for f in *; do rm -f /usr/bin/"$f"; \
    ln -s ../lib/llvm-16/bin/"$f" /usr/bin/"$f"                                                                                                                                                                   
done


cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

git clone --filter=blob:none "${OPENVAF_REPO_URL}" "${OPENVAF_NAME}"
cd "${OPENVAF_NAME}" || exit 1
git checkout "${OPENVAF_REPO_COMMIT}"

cargo update
cargo build --release --bin openvaf-r -j$(nproc)

mkdir -p  "${TOOLS}/${OPENVAF_NAME}/bin"
strip target/release/openvaf-r
cp target/release/openvaf-r "${TOOLS}/${OPENVAF_NAME}/bin"
ln -s "${TOOLS}/${OPENVAF_NAME}/bin/openvaf-r" "${TOOLS}/${OPENVAF_NAME}/bin/openvaf"
