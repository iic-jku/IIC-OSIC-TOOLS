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

export XDG_DATA_HOME=$TOOLS/.data-default
mkdir -p "$XDG_DATA_HOME"
"${TOOLS}"/"${VERYL_NAME}"/bin/verylup setup
