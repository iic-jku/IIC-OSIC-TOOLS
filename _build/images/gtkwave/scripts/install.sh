#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GTKWAVE_REPO_URL}" "${GTKWAVE_NAME}"
cd "${GTKWAVE_NAME}" || exit 1
git checkout "${GTKWAVE_REPO_COMMIT}"

meson setup build --prefix="${TOOLS}/${GTKWAVE_NAME}"
mkdir -p build/include
meson compile -C build
meson install -C build

# Fix RPATH: libfst is built as a meson subproject and installed into the
# gtkwave libdir, but gtkwave's meson.build does not set install_rpath on
# all targets (e.g. rtlbrowse, libgtkwave.so).  Without RPATH, the ELF
# binaries cannot find libfst.so.1 unless LD_LIBRARY_PATH is set.
LIBDIR="${TOOLS}/${GTKWAVE_NAME}/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
apt-get -y install --no-install-recommends patchelf
patchelf --set-rpath "${LIBDIR}" "${LIBDIR}/libgtkwave.so"
patchelf --set-rpath "${LIBDIR}" "${TOOLS}/${GTKWAVE_NAME}/bin/rtlbrowse"

echo "${GTKWAVE_NAME} ${GTKWAVE_REPO_COMMIT}" > "${TOOLS}/${GTKWAVE_NAME}/SOURCES"
