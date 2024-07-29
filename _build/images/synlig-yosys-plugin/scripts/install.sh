#!/bin/bash
#set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SYNLIG_YOSYS_PLUGIN_REPO_URL}" "${SYNLIG_YOSYS_PLUGIN_NAME}"
cd "${SYNLIG_YOSYS_PLUGIN_NAME}" || exit 1
git checkout "${SYNLIG_YOSYS_PLUGIN_REPO_COMMIT}"
git submodule sync
git submodule update --init --recursive third_party/{surelog,yosys}
make -j"$(nproc)" @systemverilog-plugin
mkdir -p "${TOOLS}_add/yosys/share/yosys/plugins"
cp out/current/share/yosys/plugins/systemverilog.so "${TOOLS}_add/yosys/share/yosys/plugins"
