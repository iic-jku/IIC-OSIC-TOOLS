#!/bin/bash
set -e
mkdir -p "${TOOLS}/${FPGA_NAME}/bin"

# Install icestorm
# ----------------
cd /tmp || exit 1
echo "[INFO] Installing icestorm"
git clone --depth=1 https://github.com/YosysHQ/icestorm.git
cd icestorm || exit 1
PREFIX="${TOOLS}/${FPGA_NAME}" make -j"$(nproc)"
PREFIX="${TOOLS}/${FPGA_NAME}" make install

# Install nextpnr
# -----------------
cd /tmp || exit 1
echo "[INFO] Installing nextpnr"
git clone --depth=1 https://github.com/YosysHQ/nextpnr.git
cd nextpnr || exit 1
mkdir -p build && cd build || exit 1
cmake ..    -DARCH=ice40 \
            -DCMAKE_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DICESTORM_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}"
make -j"$(nproc)"
make install
strip "${TOOLS}/${FPGA_NAME}/bin/nextpnr-ice40"

# Compress large icestorm files
# -----------------------------
gzip -f "${TOOLS}/${FPGA_NAME}"/share/icebox/*
