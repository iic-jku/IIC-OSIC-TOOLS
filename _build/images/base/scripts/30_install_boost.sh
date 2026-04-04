#!/bin/bash

set -e

# Install Boost 1.88 from source (replaces Ubuntu 24.04 system Boost 1.83)
# Required by: OpenROAD, OpenROAD-LibreLane, VACASK, KLayout, and others
BOOST_VERSION="1.88.0"
echo "[INFO] Installing BOOST version $BOOST_VERSION"
cd /tmp
wget --no-verbose "https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//./_}.tar.gz"
tar -xf "boost_${BOOST_VERSION//./_}.tar.gz"
cd "boost_${BOOST_VERSION//./_}"
./bootstrap.sh --prefix=/usr/local --with-python=python3
./b2 install -j "$(nproc)" \
    --with-filesystem \
    --with-iostreams \
    --with-program_options \
    --with-python \
    --with-serialization \
    --with-system \
    --with-test \
    --with-thread \
    --with-process \
    --with-asio \
    link=shared \
    threading=multi \
    variant=release

ldconfig

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
