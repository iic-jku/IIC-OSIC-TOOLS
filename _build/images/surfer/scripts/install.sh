#!/bin/bash
set -e
cd /tmp || exit 1

# install rust toolchain via rustup (surfer needs newer rust compiler than available in Ubuntu 24.04 LTS)
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
export RUSTUP_INIT_SKIP_PATH_CHECK=yes

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh --no-modify-path -y

# install surfer
cargo install --git ${SURFER_REPO_URL} --tag ${SURFER_REPO_COMMIT} surfer --root "${TOOLS}/${SURFER_NAME}" --locked
