#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

# OpenROAD deprecated its CMake build (removal on Nov. 1, 2026), Bazel is the
# supported build system. Bazel fetches a hermetic LLVM toolchain and all
# dependencies (Qt, Tcl, Boost, SWIG, spdlog, ...) itself; bazelisk and the
# few system libraries it links against come from base-dev.
git clone --filter=blob:none "${OPENROAD_REPO_URL}" "${OPENROAD_NAME}"
cd "${OPENROAD_NAME}" || exit 1
git checkout "${OPENROAD_REPO_COMMIT}"
git submodule update --init --recursive

# Same flags as upstream etc/Build.sh: --config=release stamps the real
# `git describe` version and includes --config=opt (-O3, ThinLTO).
BAZEL_ARGS=("--jobs=$(nproc)" "--config=release" "--//:platform=gui")
# On aarch64, qt-bazel links the real system X11/xcb/xkbcommon libraries
# instead of interface stubs. These need newer glibc symbol versions (e.g.
# __isoc23_strtol@GLIBC_2.38) than the toolchain's glibc 2.28 link stubs
# provide, so lld's default --no-allow-shlib-undefined fails the link. The
# system glibc resolves them at runtime, so let the link through.
if [ "$(arch)" == "aarch64" ]; then
    BAZEL_ARGS+=("--linkopt=-Wl,--allow-shlib-undefined")
fi
bazelisk build "${BAZEL_ARGS[@]}" //:openroad //src/sta:opensta
bazelisk run "${BAZEL_ARGS[@]}" //:install -- "${TOOLS}/${OPENROAD_NAME}"
# //:install only ships openroad; add the standalone OpenSTA binary as the
# CMake build did (used as OPENSTA_EXE by ORFS)
install -m 755 bazel-bin/src/sta/opensta "${TOOLS}/${OPENROAD_NAME}/bin/sta"

# Get ORFS GitHub hash that works with this OR version
ORFS_COMMIT=$(git ls-remote https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git HEAD | cut -f 1)
echo "$ORFS_COMMIT" > "${TOOLS}/${OPENROAD_NAME}/ORFS_COMMIT"

# Drop the Bazel output base and caches (many GB), they are build-time only
bazelisk shutdown
rm -rf "${HOME}/.cache/bazel" "${HOME}/.cache/bazel-disk-cache" "${HOME}/.cache/bazel-repository-cache" "${HOME}/.cache/bazelisk"

echo "${OPENROAD_NAME} ${OPENROAD_REPO_COMMIT}" > "${TOOLS}/${OPENROAD_NAME}/SOURCES"
