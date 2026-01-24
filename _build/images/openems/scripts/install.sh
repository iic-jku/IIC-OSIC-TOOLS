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
cmake -DBUILD_APPCSXCAD=NO -DCMAKE_INSTALL_PREFIX="${TOOLS}/$OPENEMS_NAME" -DWITH_MPI=0 ..
make -j${nproc}

cd /tmp/"$OPENEMS_NAME"/openEMS/python || exit 1
python3 setup.py build_ext -I ${TOOLS}/${OPENEMS_NAME}/include -L ${TOOLS}/${OPENEMS_NAME}/lib  -R ${TOOLS}/${OPENEMS_NAME}/lib
python3 setup.py install --prefix "${TOOLS}/${OPENEMS_NAME}"

cd /tmp/"$OPENEMS_NAME"/CSXCAD/python || exit 1
python3 setup.py build_ext -I ${TOOLS}/${OPENEMS_NAME}/include -L ${TOOLS}/${OPENEMS_NAME}/lib  -R ${TOOLS}/${OPENEMS_NAME}/lib
python3 setup.py install --prefix "${TOOLS}/${OPENEMS_NAME}"
