#!/bin/bash
set -e
cd /tmp || exit 1

# On x86_64, restrict to x86-64-v2 to avoid AVX-512 instructions that are not
# available on most consumer CPUs (build machines may support AVX-512).
if [ "$(uname -m)" = "x86_64" ]; then
    MARCH_FLAGS="-march=x86-64-v2"
    OPENVAF_OPTIONS="--target-cpu x86-64-v2"
else
    MARCH_FLAGS=""
    OPENVAF_OPTIONS=""
fi

# Install custom libboost since stock libboost version is too old
curl -LO https://archives.boost.io/release/1.88.0/source/boost_1_88_0.tar.gz
tar xvf boost_1_88_0.tar.gz
cd boost_1_88_0/tools/build
./bootstrap.sh gcc
cd ../..
# Pass architecture flags to Boost as well.
tools/build/b2 --with-filesystem --with-process --with-asio link=static toolset=gcc \
    cxxflags="${MARCH_FLAGS}" cflags="${MARCH_FLAGS}"
cd ..

git clone --branch "${VACASK_REPO_COMMIT}" "${VACASK_REPO_URL}" "${VACASK_NAME}"
cd "${VACASK_NAME}" || exit 1

mkdir -p build && cd build
cmake -G Ninja -S .. -B . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="${MARCH_FLAGS}" \
    -DCMAKE_C_FLAGS="${MARCH_FLAGS}" \
    -DOPENVAF_OPTIONS="${OPENVAF_OPTIONS}" \
    -DOPENVAF_DIR="${TOOLS}/openvaf/bin" \
    -DBoost_ROOT=/tmp/boost_1_88_0/stage
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Remove openvaf here since it is already installed with openvaf-r.
rm -rf ${TOOLS}/${VACASK_NAME}/bin/openvaf-r
