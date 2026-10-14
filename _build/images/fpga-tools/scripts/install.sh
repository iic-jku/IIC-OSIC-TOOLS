#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

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

# Install prjtrellis (Lattice ECP5)
# ---------------------------------
# Provides ecppack and the ECP5 database. It must be installed before nextpnr's
# cmake runs, because nextpnr-ecp5 builds its chipdb from this install
# (FindTrellis looks for pytrellis in lib/trellis, where libtrellis installs it).
cd /tmp || exit 1
echo "[INFO] Installing prjtrellis"
git clone --filter=blob:none "${PRJTRELLIS_REPO_URL}" prjtrellis
cd prjtrellis || exit 1
git checkout "${PRJTRELLIS_REPO_COMMIT}"
git submodule update --init --recursive
cd libtrellis || exit 1
cmake -DCMAKE_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" .
make -j"$(nproc)"
make install

# Only the ECP5 family of the database is usable here (nextpnr is built for
# ice40 and ecp5, and ecppack is ECP5-only), so drop the MachXO* families,
# 26 of the 86 MB. The ECP5 part has to stay in the image: ecppack loads the
# database at run time to map the place-and-route result onto bitstream frames.
rm -rf "${TOOLS}/${FPGA_NAME}"/share/trellis/database/MachXO*

# Install nextpnr (iCE40 and ECP5 in one build)
# ---------------------------------------------
cd /tmp || exit 1
echo "[INFO] Installing nextpnr"
git clone --filter=blob:none "${NEXTPNR_REPO_URL}" nextpnr
cd nextpnr || exit 1
git checkout "${NEXTPNR_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build || exit 1
cmake ..    -DARCH="ice40;ecp5" \
            -DUSE_OPENMP=yes \
            -DCMAKE_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DICESTORM_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DTRELLIS_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}"
make -j"$(nproc)"
make install
strip "${TOOLS}/${FPGA_NAME}"/bin/nextpnr-ice40 "${TOOLS}/${FPGA_NAME}"/bin/nextpnr-ecp5

# Compress large icestorm files
# -----------------------------
gzip -f "${TOOLS}/${FPGA_NAME}"/share/icebox/*

echo "icestorm ${ICESTORM_REPO_COMMIT}" > "${TOOLS}/${FPGA_NAME}/SOURCES"
echo "prjtrellis ${PRJTRELLIS_REPO_COMMIT}" >> "${TOOLS}/${FPGA_NAME}/SOURCES"
echo "nextpnr ${NEXTPNR_REPO_COMMIT}" >> "${TOOLS}/${FPGA_NAME}/SOURCES"
