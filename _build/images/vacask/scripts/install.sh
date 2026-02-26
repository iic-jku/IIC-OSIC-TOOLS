#!/bin/bash
set -e
cd /tmp || exit 1

# Install custom libboost since stock libboost version is too old
curl -LO https://archives.boost.io/release/1.88.0/source/boost_1_88_0.tar.gz
tar xvf boost_1_88_0.tar.gz
cd boost_1_88_0/tools/build
./bootstrap.sh gcc
cd ../..
tools/build/b2 --with-filesystem --with-process --with-asio link=static toolset=gcc
cd ..

git clone --branch "${VACASK_REPO_COMMIT}" "${VACASK_REPO_URL}" "${VACASK_NAME}"
cd "${VACASK_NAME}" || exit 1

mkdir -p build && cd build
cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release -DOPENVAF_DIR="${TOOLS}/openvaf/bin" -DBoost_ROOT=/tmp/boost_1_88_0/stage
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Remove openvaf here since it is already installed with openvaf-r.
rm -rf "${TOOLS}/${VACASK_NAME}/bin/openvaf-r"
