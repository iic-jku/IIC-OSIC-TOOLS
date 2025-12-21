#!/bin/bash
set -e
cd /tmp || exit 1

git clone --branch "${VACASK_REPO_COMMIT}" "${VACASK_REPO_URL}" "${VACASK_NAME}"
cd "${VACASK_NAME}" || exit 1

#FIXME: remove failing lines from jfet2.va to allow compilation to complete
sed -i '/pwr =/d' devices/spice/full/jfet2.va

mkdir -p build && cd build
cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release -DOPENVAF_DIR=${TOOLS}/openvaf/bin
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Remove openvaf here since it is already installed with openvaf-r.
rm -rf ${TOOLS}/${VACASK_NAME}/bin/openvaf-r
