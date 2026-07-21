#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

# slang >= v11 requires Boost >= 1.86 for <boost/unordered/concurrent_flat_set.hpp>.
# Ubuntu 24.04 ships Boost 1.83 (which has concurrent_flat_map.hpp but NOT
# concurrent_flat_set.hpp), so __has_include picks the system path and fails.
# Build a newer header-only Boost in /tmp and point find_package(Boost CONFIG) at it.
BOOST_VERSION="1.88.0"
BOOST_DIR="boost_${BOOST_VERSION//./_}"
BOOST_ARCHIVE="${BOOST_DIR}.tar.gz"

wget -q "https://archives.boost.io/release/${BOOST_VERSION}/source/${BOOST_ARCHIVE}"
tar xf "${BOOST_ARCHIVE}"
cd "${BOOST_DIR}/tools/build"
./bootstrap.sh gcc
cd ../..
# Headers only are sufficient for slang (it links Boost::headers).
tools/build/b2 -j "$(nproc)" headers
cd /tmp

git clone --filter=blob:none "${SLANG_REPO_URL}" "${SLANG_NAME}"
cd "${SLANG_NAME}" || exit 1
git checkout "${SLANG_REPO_COMMIT}"
cmake -B build -DSLANG_INCLUDE_TESTS=OFF \
    -DBoost_ROOT="/tmp/${BOOST_DIR}" \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBOOST_INCLUDEDIR="/tmp/${BOOST_DIR}" \
    -DCMAKE_CXX_FLAGS="-isystem /tmp/${BOOST_DIR}"
cmake --build build -j"$(nproc)"
cmake --install build --strip --prefix="${TOOLS}/${SLANG_NAME}"

echo "${SLANG_NAME} ${SLANG_REPO_COMMIT}" > "${TOOLS}/${SLANG_NAME}/SOURCES"

# Cleanup
cd /tmp && rm -rf "${BOOST_DIR}" "${BOOST_ARCHIVE}" "${SLANG_NAME}"
