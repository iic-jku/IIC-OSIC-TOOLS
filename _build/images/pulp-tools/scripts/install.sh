#!/bin/bash
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
git clone --depth=1 https://github.com/pulp-platform/bender.git
cd bender || exit 1
cargo update
cargo build --release -j"$(nproc)"
strip target/release/bender
cp target/release/bender "${TOOLS}/${PULP_NAME}/bin"

# Install Verible
# ---------------
cd /tmp || exit 1
# we don't build locally (too many strange dependencies), but get the binary instead
echo "[INFO] Installing Verible"
if [ "$(arch)" == "aarch64" ]; then
    CPUID="arm64"
else
    CPUID="x86_64"
fi
LOC=https://github.com/chipsalliance/verible/releases/download/v0.0-3724-gdec56671
FILE=verible-v0.0-3724-gdec56671-linux-static-${CPUID}.tar.gz
wget --no-verbose $LOC/$FILE && tar xfz $FILE && rm -f $FILE
cp verible*/bin/* "${TOOLS}/${PULP_NAME}/bin"

# Build SV2V
# ----------
cd /tmp || exit 1
echo "[INFO] Building SV2V"
# get Haskell stack first
wget -qO- https://get.haskellstack.org/ | sh
# now build SV2V using Haskell and Stack
git clone --depth=1 https://github.com/zachjs/sv2v.git
cd sv2v || exit 1
stack install --install-ghc --local-bin-path bin --stack-root /tmp/stack
strip bin/sv2v
cp bin/sv2v "${TOOLS}/${PULP_NAME}/bin"
