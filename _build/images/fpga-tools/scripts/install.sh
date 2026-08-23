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
# Provides ecppack and the ECP5 database that nextpnr-ecp5 builds its chipdb from.
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

# Install apycula (Gowin)
# -----------------------
# Provides gowin_pack and the Gowin device database that nextpnr's Himbaechel
# Gowin uarch builds its chipdb from. The git tree only carries the fuzzers, the
# database itself is generated from the vendor IDE, so the released package is
# the only installable form and the pin is a version rather than a commit.
echo "[INFO] Installing apycula ${APYCULA_REPO_COMMIT}"
pip3 install "apycula==${APYCULA_REPO_COMMIT}" --prefix="${TOOLS}/${FPGA_NAME}" --no-cache-dir

# Ubuntu's pip applies the posix_local scheme even with --prefix, so gowin_pack
# and friends land in local/bin, which install_links.sh does not look at (it
# globs ${TOOLS}/*/bin/*). Move them where the rest of the image expects them.
# The shebangs are absolute, so moving the files does not break them.
if [ -d "${TOOLS}/${FPGA_NAME}/local/bin" ]; then
	mv "${TOOLS}/${FPGA_NAME}"/local/bin/* "${TOOLS}/${FPGA_NAME}/bin/"
	rmdir "${TOOLS}/${FPGA_NAME}/local/bin"
fi

# nextpnr generates its Gowin chipdbs by running gowin_arch_gen.py with the
# system python3, which imports apycula, so the fresh install has to be on
# PYTHONPATH before cmake runs.
export PATH="${TOOLS}/${FPGA_NAME}/bin:${PATH}"
for d in "${TOOLS}/${FPGA_NAME}"/local/lib/python3*/dist-packages "${TOOLS}/${FPGA_NAME}"/lib/python3*/site-packages; do
	[ -d "${d}" ] && export PYTHONPATH="${d}${PYTHONPATH:+:${PYTHONPATH}}"
done

# Install nextpnr (iCE40, ECP5, and Gowin through Himbaechel)
# -----------------------------------------------------------
cd /tmp || exit 1
echo "[INFO] Installing nextpnr"
git clone --filter=blob:none "${NEXTPNR_REPO_URL}" nextpnr
cd nextpnr || exit 1
git checkout "${NEXTPNR_REPO_COMMIT}"
git submodule update --init --recursive
mkdir -p build && cd build || exit 1
cmake ..    -DARCH="ice40;ecp5;himbaechel" \
            -DHIMBAECHEL_UARCH=gowin \
            -DHIMBAECHEL_GOWIN_DEVICES=all \
            -DUSE_OPENMP=yes \
            -DCMAKE_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DICESTORM_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}" \
            -DTRELLIS_INSTALL_PREFIX="${TOOLS}/${FPGA_NAME}"
make -j"$(nproc)"
make install
strip "${TOOLS}/${FPGA_NAME}"/bin/nextpnr-*

# Compress large icestorm files
# -----------------------------
gzip -f "${TOOLS}/${FPGA_NAME}"/share/icebox/*

echo "icestorm ${ICESTORM_REPO_COMMIT}" > "${TOOLS}/${FPGA_NAME}/SOURCES"
echo "prjtrellis ${PRJTRELLIS_REPO_COMMIT}" >> "${TOOLS}/${FPGA_NAME}/SOURCES"
echo "apycula ${APYCULA_REPO_COMMIT}" >> "${TOOLS}/${FPGA_NAME}/SOURCES"
echo "nextpnr ${NEXTPNR_REPO_COMMIT}" >> "${TOOLS}/${FPGA_NAME}/SOURCES"
