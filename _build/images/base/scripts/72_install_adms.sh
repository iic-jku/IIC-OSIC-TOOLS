#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Need to compile ADMS manually, as version available via APT is outdated
# ADMS is currently only used by Xyce to compile Verilog-A models

echo "[INFO] Installing ADMS"
cd /tmp || exit 1
git clone --depth=1 https://github.com/Qucs/ADMS.git adms
cd adms || exit 1
# CMake 4 rejects the cmake_policy(SET CMP0048 OLD) and the
# cmake_minimum_required(VERSION 2.8) of ADMS. Drop both workarounds once
# Qucs/ADMS fixes its CMakeLists.txt. -std=gnu17: its sources declare
# verilogaparse() without a prototype and call it with an argument, an error in
# the C23 default of GCC 15.
sed -i '/cmake_policy(SET CMP0048 OLD)/d' CMakeLists.txt
cmake -B build -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_C_FLAGS=-std=gnu17 -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build -j "$(nproc)" --target install

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
