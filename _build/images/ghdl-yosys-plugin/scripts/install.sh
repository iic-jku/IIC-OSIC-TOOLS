#!/bin/bash
set -e
cd /tmp || exit 1

# shellcheck disable=SC2010
export PATH="$PATH:$TOOLS/yosys/bin:$TOOLS/ghdl/bin"
echo "[INFO] PATH=$PATH"

git clone --filter=blob:none "${GHDL_YOSYS_PLUGIN_REPO_URL}" "${GHDL_YOSYS_PLUGIN_NAME}"
cd "${GHDL_YOSYS_PLUGIN_NAME}" || exit 1
git checkout "${GHDL_YOSYS_PLUGIN_REPO_COMMIT}"
make -j"$(nproc)"
mkdir -p "${TOOLS}_add/yosys/share/yosys/plugins"
cp ghdl.so "${TOOLS}_add/yosys/share/yosys/plugins"
