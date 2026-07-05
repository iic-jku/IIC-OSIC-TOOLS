#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
mkdir -p "${TOOLS}/${PULP_NAME}/bin"
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

# Build Bender
# ------------
cd /tmp || exit 1
echo "[INFO] Building Bender"
git clone --filter=blob:none "${BENDER_REPO_URL}" bender
cd bender || exit 1
git checkout "${BENDER_REPO_COMMIT}"
cargo update
cargo build --release -j"$(nproc)"
strip target/release/bender
cp target/release/bender "${TOOLS}/${PULP_NAME}/bin"

# NOTE: Verible is provided by the dedicated 'verible' tool image (built from
# source, see images/verible). It was previously bundled here as a prebuilt
# binary, which shipped a second, older Verible that shadowed the standalone
# one on PATH. Removed to keep a single source of truth.

# Build SV2V
# ----------
cd /tmp || exit 1
echo "[INFO] Building SV2V"
# get Haskell stack first
wget -qO- https://get.haskellstack.org/ | sh
# now build SV2V using Haskell and Stack
git clone --filter=blob:none "${SV2V_REPO_URL}" sv2v
cd sv2v || exit 1
git checkout "${SV2V_REPO_COMMIT}"
stack install --install-ghc --local-bin-path bin --stack-root /tmp/stack
strip bin/sv2v
cp bin/sv2v "${TOOLS}/${PULP_NAME}/bin"

echo "bender ${BENDER_REPO_COMMIT}" > "${TOOLS}/${PULP_NAME}/SOURCES"
echo "sv2v ${SV2V_REPO_COMMIT}" >> "${TOOLS}/${PULP_NAME}/SOURCES"
