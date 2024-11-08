#!/bin/bash

set -e

# Install cudd (dependency of OpenROAD)
CUDD_PREFIX="/usr/local"
CUDD_VERSION=3.0.0
echo "[INFO] Installing CUDD version $CUDD_VERSION into $CUDD_PREFIX"
cd /tmp || exit 1
git clone --depth=1 -b "$CUDD_VERSION" https://github.com/The-OpenROAD-Project/cudd.git
cd cudd || exit 1
autoreconf
./configure --prefix="$CUDD_PREFIX"
make -j "$(nproc)" install
rm -rf /tmp/*
