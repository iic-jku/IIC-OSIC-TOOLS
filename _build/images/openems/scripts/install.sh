#!/bin/bash
# Install OpenEMS and the required dependencies (fparser, CSXCAD, QCSXCAD) as well as applications (AppCSXCAD)
set -e

# Required dependencies
# apt -y install libcgal-dev libhdf5-dev libvtk9-dev libtinyxml-dev cython3 libvtk9-qt-dev
# Only for hyp2mat or CTB (which is disabled for now)
# apt -y install libhpdf-dev

cd /tmp || exit 1
git clone --filter=blob:none "$OPENEMS_REPO_URL" "$OPENEMS_NAME"
cd "$OPENEMS_NAME"
git checkout "$OPENEMS_REPO_COMMIT"
git submodule update --init --recursive
#  --with-hyp2mat disabled for now because of strange build error.
# Install python separately, because of old/outdated way of installing
#./update_openEMS.sh --with-CTB "${TOOLS}/$OPENEMS_NAME"

mkdir build
cd build || exit 1
cmake -DBUILD_APPCSXCAD=YES -DCMAKE_INSTALL_PREFIX="${TOOLS}/$OPENEMS_NAME" -DWITH_MPI=0 ..
make -j"$(nproc)"

export OPENEMS_INSTALL_PATH="${TOOLS}/${OPENEMS_NAME}"
export CSXCAD_INSTALL_PATH="${TOOLS}/${OPENEMS_NAME}"

# Determine the Python site-packages path under our install prefix
PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
SITE_PKG="${TOOLS}/${OPENEMS_NAME}/lib/python${PYVER}/site-packages"
mkdir -p "$SITE_PKG"
# Include CSXCAD source directory so Cython can resolve .pxd files during openEMS build
export PYTHONPATH="/tmp/${OPENEMS_NAME}/CSXCAD/python:${SITE_PKG}:${PYTHONPATH:-}"

# CSXCAD Python bindings must be built first (openEMS depends on CSXCAD .pxd files)
cd /tmp/"$OPENEMS_NAME"/CSXCAD/python || exit 1
pip3 install . --no-build-isolation --prefix="${TOOLS}/${OPENEMS_NAME}" --break-system-packages

cd /tmp/"$OPENEMS_NAME"/openEMS/python || exit 1
pip3 install . --no-build-isolation --no-deps --prefix="${TOOLS}/${OPENEMS_NAME}" --break-system-packages

echo "${OPENEMS_NAME} ${OPENEMS_REPO_COMMIT}" > "${TOOLS}/${OPENEMS_NAME}/SOURCES"
