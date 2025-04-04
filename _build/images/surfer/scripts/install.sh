#!/bin/bash
set -e
cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

git clone --depth=1 "${SURFER_REPO_URL}" "${SURFER_NAME}"
cd "${SURFER_NAME}" || exit 1
git checkout "${SURFER_REPO_COMMIT}"
git submodule update --init --recursive
cargo install surfer --root "${TOOLS}/${SURFER_NAME}" --locked
