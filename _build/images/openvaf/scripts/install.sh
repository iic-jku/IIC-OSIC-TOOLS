#!/bin/bash

set -e
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
cp target/release/openvaf-r "${TOOLS}/${OPENVAF_NAME}/bin"
ln -s "${TOOLS}/${OPENVAF_NAME}/bin/openvaf-r" "${TOOLS}/${OPENVAF_NAME}/bin/openvaf"
