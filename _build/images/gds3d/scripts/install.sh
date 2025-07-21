#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${GDS3D_REPO_URL}" "${GDS3D_NAME}"
cd "${GDS3D_NAME}" || exit 1
git checkout "${GDS3D_REPO_COMMIT}"
#fix for GCC-11, see https://github.com/trilomix/GDS3D/pull/9
sed -i -e '/CFLAGS=/ s/$/ -std=c++11/' linux/Makefile

make -C linux -j"$(nproc)"

mkdir -p "${TOOLS}/${GDS3D_NAME}/bin"
cp linux/GDS3D "${TOOLS}/${GDS3D_NAME}/bin"

if [ -d "$PDK_ROOT/sky130A" ]; then
    mkdir -p "$PDK_ROOT/sky130A/libs.tech/gds3d"
    cp techfiles/sky130.txt "$PDK_ROOT/sky130A/libs.tech/gds3d/gds3d_tech.txt"
fi

if [ -d "$PDK_ROOT/sky130B" ]; then
    mkdir -p "$PDK_ROOT/sky130B/libs.tech/gds3d"
    cp techfiles/sky130.txt "$PDK_ROOT/sky130B/libs.tech/gds3d/gds3d_tech.txt"
fi

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s "${TOOLS}/${GDS3D_NAME}/bin/*" .
