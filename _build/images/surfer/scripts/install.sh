#!/bin/bash
set -e
cd /tmp || exit 1

export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

cargo update
cargo install --git ${SURFER_REPO_URL} --tag ${SURFER_REPO_COMMIT} surfer --root "${TOOLS}/${SURFER_NAME}" --locked
