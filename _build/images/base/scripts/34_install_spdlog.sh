#!/bin/bash

set -e

# Install spdlog (dependency of OpenROAD)
#SPDLOG_PREFIX="/usr/local"
#SPDLOG_VERSION=1.8.1
#echo "[INFO] Installing SPDLOG version $SPDLOG_VERSION into $SPDLOG_PREFIX"
#cd /tmp || exit 1
#git clone --depth=1 -b "v${SPDLOG_VERSION}" https://github.com/gabime/spdlog.git
#cd spdlog || exit 1
#cmake -DCMAKE_INSTALL_PREFIX="${SPDLOG_PREFIX}" -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPDLOG_BUILD_EXAMPLE=OFF -B build .
#cmake --build build -j "$(nproc)" --target install
#rm -rf /tmp/*
