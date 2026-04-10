#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

export PATH="$PATH:$TOOLS/yosys/bin:$TOOLS/ghdl/bin"
echo "[INFO] PATH=$PATH"

git clone --filter=blob:none "${SLANG_YOSYS_PLUGIN_REPO_URL}" "${SLANG_YOSYS_PLUGIN_NAME}"
cd "${SLANG_YOSYS_PLUGIN_NAME}" || exit 1
git checkout "${SLANG_YOSYS_PLUGIN_REPO_COMMIT}"
git submodule update --init --recursive
make -j"$(nproc)"

mkdir -p "${TOOLS}/${SLANG_YOSYS_PLUGIN_NAME}"
cp build/slang.so "${TOOLS}/${SLANG_YOSYS_PLUGIN_NAME}"
echo "${SLANG_YOSYS_PLUGIN_NAME} ${SLANG_YOSYS_PLUGIN_REPO_COMMIT}" > "${TOOLS}/${SLANG_YOSYS_PLUGIN_NAME}/SOURCES"
