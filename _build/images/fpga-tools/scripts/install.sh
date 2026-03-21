#!/bin/bash
set -e
mkdir -p "${TOOLS}/${FPGA_NAME}/bin"

# Install icestorm (Lattice iCE40)
# --------------------------------
cd /tmp || exit 1
echo "[INFO] Installing icestorm"
git clone --filter=blob:none "${ICESTORM_REPO_URL}" icestorm
cd icestorm || exit 1
git checkout "${ICESTORM_REPO_COMMIT}"
PREFIX="${TOOLS}/${FPGA_NAME}" make -j"$(nproc)"
PREFIX="${TOOLS}/${FPGA_NAME}" make install

# Install nextpnr
# -----------------
cd /tmp || exit 1
echo "[INFO] Installing nextpnr"
git clone --filter=blob:none "${NEXTPNR_REPO_URL}" nextpnr
cd nextpnr || exit 1
git checkout "${NEXTPNR_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build || exit 1
cmake ..    -DARCH=ice40 \
            -DUSE_OPENMP=yes \
            -DCMAKE_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DICESTORM_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}"
make -j"$(nproc)"
make install
strip "${TOOLS}/${FPGA_NAME}/bin/nextpnr-ice40"

# Compress large icestorm files
# -----------------------------
gzip -f "${TOOLS}/${FPGA_NAME}"/share/icebox/*
