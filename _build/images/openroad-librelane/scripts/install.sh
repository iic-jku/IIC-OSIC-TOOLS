#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

# Unlike images/openroad, this image keeps the deprecated CMake build: the Bazel
# build compiles OpenROAD without ENABLE_PYTHON3, and LibreLane's Odb steps run
# `openroad -python`. LibreLane's own nix build uses CMake for the same reason.
# Switch to Bazel once the pinned revision drops CMake, if Bazel builds Python
# by then.

# OpenROAD needs spdlog >= 1.15, so we update it here
SPDLOG_PREFIX="/usr/local"
SPDLOG_VERSION=1.15.1
echo "[INFO] Installing SPDLOG version $SPDLOG_VERSION into $SPDLOG_PREFIX"
git clone --depth=1 -b "v${SPDLOG_VERSION}" https://github.com/gabime/spdlog.git
cd spdlog || exit 1
cmake -DCMAKE_INSTALL_PREFIX="${SPDLOG_PREFIX}" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPDLOG_BUILD_EXAMPLE=OFF -B build .
cmake --build build -j "$(nproc)" --target install
cd /tmp || exit 1

# OpenROAD 26Q4 requires SWIG >= 4.3, Ubuntu 24.04 ships 4.2. Build the version
# that OpenROAD's etc/DependencyInstaller.sh installs. Drop once the base image
# ships SWIG >= 4.3.
SWIG_PREFIX="/usr/local"
SWIG_VERSION=4.3.0
echo "[INFO] Installing SWIG version $SWIG_VERSION into $SWIG_PREFIX"
git clone --depth=1 -b "v${SWIG_VERSION}" https://github.com/swig/swig.git
cd swig || exit 1
./autogen.sh
./configure --prefix="${SWIG_PREFIX}"
make -j"$(nproc)"
make install
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${OPENROAD_LIBRELANE_REPO_URL}" "${OPENROAD_LIBRELANE_NAME}"
cd "${OPENROAD_LIBRELANE_NAME}" || exit 1
git checkout "${OPENROAD_LIBRELANE_REPO_COMMIT}"
git submodule update --init --recursive --filter=blob:none

# LibreLane's nix build applies this patch on top of its pinned OpenROAD revision
# (vendored from librelane 3.1.0.dev6, nix/patches/openroad/fix_pad_connections.patch).
# Apply it here as well so our binary matches the official LibreLane one. Re-check
# whether it is still carried when bumping the librelane or OpenROAD pin.
git apply /images/openroad-librelane/patches/fix_pad_connections.patch

# Same fix as images/openroad: the DEF and LEF lexers store GETC()/lefGetc()
# (an int) in `char fc` and then test fc == EOF. char is unsigned on aarch64,
# so the test is always false there and EOF inside a comment never terminates.
# The CMake build only warns (ALLOW_WARNINGS is on by default), so here it is a
# runtime fix, not a build fix. Not reported upstream yet, drop once both files
# declare fc as int.
for KEYWORDS in src/odb/src/def/def/def_keywords.cpp src/odb/src/lef/lef/lef_keywords.cpp; do
    sed -i 's/^  char fc;$/  int fc;/' "$KEYWORDS"
    grep -q '^  int fc;$' "$KEYWORDS" || { echo "[ERROR] char fc not found in $KEYWORDS, check whether the patch is still needed"; exit 1; }
done

# FindSWIG tries the name swig4.0 before swig and would pick /usr/bin/swig4.0
cmake -B build \
    -DCMAKE_INSTALL_PREFIX="${TOOLS}/${OPENROAD_LIBRELANE_NAME}" \
    -DUSE_SYSTEM_BOOST=ON \
    -DENABLE_TESTS=OFF \
    -DBUILD_GUI=ON \
    -DSWIG_EXECUTABLE="${SWIG_PREFIX}/bin/swig"
cmake --build build -j "$(nproc)" --target install
# LibreLane's STA steps call the standalone `sta`. The CMake install ships it
# from the OpenSTA submodule (images/openroad adds it by hand after Bazel).
[ -x "${TOOLS}/${OPENROAD_LIBRELANE_NAME}/bin/sta" ] || { echo "[ERROR] sta not installed"; exit 1; }

# Drop the CMake build tree (several GB), it is build-time only
cd /tmp || exit 1
rm -rf "${OPENROAD_LIBRELANE_NAME}" spdlog swig

echo "${OPENROAD_LIBRELANE_NAME} ${OPENROAD_LIBRELANE_REPO_COMMIT}" > "${TOOLS}/${OPENROAD_LIBRELANE_NAME}/SOURCES"
