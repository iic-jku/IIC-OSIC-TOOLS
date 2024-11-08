#!/bin/bash
#set -e
cd /tmp || exit 1

# shellcheck disable=SC2010
export PATH="$PATH:$TOOLS/yosys/bin:$TOOLS/ghdl/bin"
echo "[INFO] PATH=$PATH"

git clone --recursive --filter=blob:none "${SLANG_YOSYS_PLUGIN_REPO_URL}" "${SLANG_YOSYS_PLUGIN_NAME}"
cd "${SLANG_YOSYS_PLUGIN_NAME}" || exit 1
git checkout "${SLANG_YOSYS_PLUGIN_REPO_COMMIT}"
make -j"$(nproc)"
mkdir -p "${TOOLS}_add/yosys/share/yosys/plugins"
cp build/slang.so "${TOOLS}_add/yosys/share/yosys/plugins"
