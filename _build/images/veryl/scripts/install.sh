#!/bin/bash

set -e
cd /tmp || exit 1
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

cargo install verylup
verylup setup
strip $CARGO_HOME/bin/veryl*
mkdir -p "${TOOLS}/${VERYL_NAME}/bin"
cp $CARGO_HOME/bin/veryl* "${TOOLS}/${VERYL_NAME}/bin"
