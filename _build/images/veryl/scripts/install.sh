#!/bin/bash

set -e
cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

mkdir -p "${TOOLS}/${VERYL_NAME}/bin"
cargo install verylup
mv $CARGO_HOME/bin/verylup "${TOOLS}/${VERYL_NAME}/bin"

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

