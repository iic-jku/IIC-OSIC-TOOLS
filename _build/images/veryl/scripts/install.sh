#!/bin/bash
set -e
cd /tmp || exit 1

export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

mkdir -p "${TOOLS}/${VERYL_NAME}/bin"
cargo install verylup --features no-self-update
mv $CARGO_HOME/bin/verylup "${TOOLS}/${VERYL_NAME}/bin"
