#!/bin/bash
set -e
mkdir -p "${TOOLS}/${PULP_NAME}/bin"

# Build Bender
# ------------
cd /tmp || exit 1
echo "[INFO] Building Bender"
git clone --depth=1 https://github.com/pulp-platform/bender.git
cd bender || exit 1
cargo build --release -j"$(nproc)"
cp target/release/bender "${TOOLS}/${PULP_NAME}/bin"

# Build Morty
# -----------
cd /tmp || exit 1
echo "[INFO] Building Morty"
git clone --depth=1 https://github.com/pulp-platform/morty.git 
cd morty || exit 1
cargo build --release -j"$(nproc)"
cp target/release/morty "${TOOLS}/${PULP_NAME}/bin"

# Build SVase
# -----------
cd /tmp || exit 1
echo "[INFO] Building SVase"
git clone --depth=1 https://github.com/pulp-platform/svase.git
cd svase || exit 1
scripts/gen_version.sh > include/version.h
cd deps || exit 1
make # -j"$(nproc)"
cd ..
mkdir build && cd build
cmake ..
make -j"$(nproc)"
cp svase "${TOOLS}/${PULP_NAME}/bin"

# Install Verible
# ---------------
cd /tmp || exit 1
# We don't build locally (too many strange dependencies), but get the binary instead
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
# Get Haskell stack first
wget -qO- https://get.haskellstack.org/ | sh
# Now build SV2V using Haskell and Stack
git clone --depth=1 https://github.com/zachjs/sv2v.git
cd sv2v || exit 1
stack install --install-ghc --local-bin-path bin --stack-root /tmp/stack
cp bin/sv2v "${TOOLS}/${PULP_NAME}/bin"
