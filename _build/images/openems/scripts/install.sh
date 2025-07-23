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
make -j${nproc}

cd /tmp/"$OPENEMS_NAME" || exit 1
pip install --no-dependencies --prefix "${TOOLS}/$OPENEMS_NAME" --global-option=build_ext --global-option="-I/foss/tools/openems/include" --global-option="-L/foss/tools/openems/lib" ./openEMS/python
pip install --no-dependencies --prefix "${TOOLS}/$OPENEMS_NAME" --global-option=build_ext --global-option="-I/foss/tools/openems/include" --global-option="-L/foss/tools/openems/lib" ./CSXCAD/python

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${OPENEMS_NAME}/bin/* .

