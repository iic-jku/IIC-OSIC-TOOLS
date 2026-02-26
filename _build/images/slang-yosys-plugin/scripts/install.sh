#!/bin/bash
#set -e
cd /tmp || exit 1

export PATH="$PATH:$TOOLS/yosys/bin:$TOOLS/ghdl/bin"
echo "[INFO] PATH=$PATH"

git clone --filter=blob:none "${SLANG_YOSYS_PLUGIN_REPO_URL}" "${SLANG_YOSYS_PLUGIN_NAME}"
cd "${SLANG_YOSYS_PLUGIN_NAME}" || exit 1
git checkout "${SLANG_YOSYS_PLUGIN_REPO_COMMIT}"
git submodule update --init --recursive
make -j"$(nproc)"
mkdir -p "${TOOLS}_add/yosys/share/yosys/plugins"
cp build/slang.so "${TOOLS}_add/yosys/share/yosys/plugins"
