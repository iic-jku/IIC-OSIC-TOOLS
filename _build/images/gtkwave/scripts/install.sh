#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GTKWAVE_REPO_URL}" "${GTKWAVE_NAME}"
cd "${GTKWAVE_NAME}" || exit 1
git checkout "${GTKWAVE_REPO_COMMIT}"

meson setup build --prefix="${TOOLS}/${GTKWAVE_NAME}"
mkdir -p build/include
meson compile -C build
meson install -C build
