#!/bin/bash
set -e
cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

git clone --branch "${SURFER_REPO_COMMIT}" "${SURFER_REPO_URL}" "${SURFER_NAME}"
cd "${SURFER_NAME}" || exit 1
git submodule update --init --recursive
cargo build --release -j"$(nproc)"
strip target/release/surfer
strip target/release/surver
mkdir -p "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/surfer "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/surver "${TOOLS}/${SURFER_NAME}/bin"
cp target/release/liblibsurfer.so "${TOOLS}/${SURFER_NAME}/bin"
