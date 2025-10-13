#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${KLAYOUT_REPO_URL}" "${KLAYOUT_NAME}"
cd "${KLAYOUT_NAME}" || exit 1
git checkout "${KLAYOUT_REPO_COMMIT}"
prefix=${TOOLS}/${KLAYOUT_NAME}
mkdir -p "$prefix"
#./build.sh -j"$(nproc)" -prefix "$prefix" -without-qtbinding
# we add the Qt-bindings again as it is needed for DRC and LVS, see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/111
./build.sh -qmake qmake6 -j "$(nproc)" -prefix "$prefix"
