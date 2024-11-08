#!/bin/bash

set -e

# Install gtest (dependency of OpenROAD)
GTEST_VERSION=1.13.0
GTEST_CHECKSUM="a1279c6fb5bf7d4a5e0d0b2a4adb39ac"
GTEST_PREFIX="/usr/local"
echo "[INFO] Installing GTEST version $GTEST_VERSION into $GTEST_PREFIX"
cd /tmp || exit 1
eval wget https://github.com/google/googletest/archive/refs/tags/v${GTEST_VERSION}.zip
md5sum -c <(echo "${GTEST_CHECKSUM} v${GTEST_VERSION}.zip") || exit 1
unzip v${GTEST_VERSION}.zip
cd googletest-${GTEST_VERSION}
cmake -DCMAKE_INSTALL_PREFIX="${GTEST_PREFIX}" -B build .
cmake --build build --target install
rm -rf /tmp/*
