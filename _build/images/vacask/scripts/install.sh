#!/bin/bash
set -euo pipefail
cd /tmp || exit 1

# Install custom libboost since stock libboost version is too old
BOOST_VERSION="1.88.0"
BOOST_DIR="boost_${BOOST_VERSION//./_}"
BOOST_ARCHIVE="${BOOST_DIR}.tar.gz"

wget -q "https://archives.boost.io/release/${BOOST_VERSION}/source/${BOOST_ARCHIVE}"
tar xf "${BOOST_ARCHIVE}"
cd "${BOOST_DIR}/tools/build"
./bootstrap.sh gcc
cd ../..
tools/build/b2 -j "$(nproc)" --with-filesystem --with-process --with-asio link=static toolset=gcc
cd ..

git clone --filter=blob:none --branch "${VACASK_REPO_COMMIT}" "${VACASK_REPO_URL}" "${VACASK_NAME}"
cd "${VACASK_NAME}" || exit 1

mkdir -p build && cd build
cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release -DOPENVAF_DIR="${TOOLS}/openvaf/bin" -DBoost_ROOT="/tmp/${BOOST_DIR}"
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Remove openvaf-r binary since it's already provided by the openvaf image.
rm -f "${TOOLS}/${VACASK_NAME}/bin/openvaf-r"

# Cleanup build artifacts
cd /tmp && rm -rf "${BOOST_DIR}" "${BOOST_ARCHIVE}" "${VACASK_NAME}"
