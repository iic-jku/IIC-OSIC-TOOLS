#!/bin/bash
# Install OpenEMS and the required dependencies (fparser, CSXCAD, QCSXCAD) as well as applications (AppCSXCAD)
set -e

# Required dependencies
# apt -y install libcgal-dev libhdf5-dev libvtk9-dev libtinyxml-dev cython3 libvtk9-qt-dev
# Only for hyp2mat or CTB (which is disabled for now)
# apt -y install libhpdf-dev

# Install CGAL from source, otherwise fail with libboost 1.88.0
cd /tmp || exit 1
wget --no-verbose https://github.com/CGAL/cgal/archive/refs/tags/v6.1.tar.gz
tar -xvf v6.1.tar.gz
cd cgal-6.1 || exit 1
cmake .
make install

# OpenEMS installation
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
make -j${nproc}
make install

# Set environment variables for Python bindings installation
export OPENEMS_INSTALL_PATH="${TOOLS}/${OPENEMS_NAME}"
export CSXCAD_INSTALL_PATH="${TOOLS}/${OPENEMS_NAME}"

cd /tmp/"$OPENEMS_NAME"/openEMS/python || exit 1
pip install --no-build-isolation --prefix "${TOOLS}/${OPENEMS_NAME}" .

cd /tmp/"$OPENEMS_NAME"/CSXCAD/python || exit 1
pip install --no-build-isolation --prefix "${TOOLS}/${OPENEMS_NAME}" .
