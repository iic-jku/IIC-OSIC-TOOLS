#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
mkdir -p "${TOOLS}/${RFTK_NAME}"

# FastHenry2 for inductance extractions
# -------------------------------------
cd /tmp || exit 1
git clone --filter=blob:none --no-checkout "${RFTK_FASTHENRY_REPO_URL}" "${RFTK_NAME}_fh"
cd "${RFTK_NAME}_fh" || exit 1
git checkout "${RFTK_FASTHENRY_REPO_COMMIT}"

# patch FastHenry Makefiles (fix thanks to Ali Olyanasab)
sed -i '/^CFLAGS/ s/$/ -fcommon -w/' src/fasthenry/Makefile
sed -i '/^CFLAGS/ s/$/ -fcommon -w/' src/fasthenry/sparse/Makefile

# remove option -m64 from Makefiles (otherwise fail on aarch64)
sed -i 's/-m64//g' src/fasthenry/Makefile
sed -i 's/-m64//g' src/misc/Makefile
sed -i 's/-m64//g' src/zbuf/Makefile
sed -i 's/-m64//g' src/fasthenry/sparse/Makefile

make all
cp -R bin "${TOOLS}/${RFTK_NAME}"
cp -R doc "${TOOLS}/${RFTK_NAME}"
cp -R examples "${TOOLS}/${RFTK_NAME}"

# FasterCap for capacitance extractions
# -------------------------------------
cd /tmp || exit 1
git clone --filter=blob:none --no-checkout "${RFTK_FASTERCAP_REPO_URL}" "${RFTK_NAME}_fc"
# get additional libs (LinAlgebra and Geometry), which CMake expects next to the
# FasterCap directory. They come from the IIC-JKU forks too. FasterCap follows its
# release tags, the libs follow their master branch, which is what the FasterCap
# fork's CI builds against.
git clone --filter=blob:none --no-checkout "${RFTK_LINALGEBRA_REPO_URL}" LinAlgebra
cd LinAlgebra || exit 1
git checkout "${RFTK_LINALGEBRA_REPO_COMMIT}"
cd ..
git clone --filter=blob:none --no-checkout "${RFTK_GEOMETRY_REPO_URL}" Geometry
cd Geometry || exit 1
git checkout "${RFTK_GEOMETRY_REPO_COMMIT}"
cd ..
# now build FasterCap
cd "${RFTK_NAME}_fc" || exit 1
git checkout "${RFTK_FASTERCAP_REPO_COMMIT}"

mkdir build && cd build
#cmake -G"CodeBlocks - Unix Makefiles" -DCMAKE_BUILD_TYPE=Release ..
cmake -G"Unix Makefiles"  -DCMAKE_BUILD_TYPE=Release -DFASTFIELDSOLVERS_HEADLESS=ON ..
make -j"$(nproc)" all
cp FasterCap "${TOOLS}/${RFTK_NAME}/bin"
ln -s "${TOOLS}/${RFTK_NAME}/bin/FasterCap" "${TOOLS}/${RFTK_NAME}/bin/fastercap"
ln -s "${TOOLS}/${RFTK_NAME}/bin/FasterCap" "${TOOLS}/${RFTK_NAME}/bin/fastcap"

echo "fasthenry ${RFTK_FASTHENRY_REPO_COMMIT}" > "${TOOLS}/${RFTK_NAME}/SOURCES"
echo "fastercap ${RFTK_FASTERCAP_REPO_COMMIT}" >> "${TOOLS}/${RFTK_NAME}/SOURCES"
echo "linalgebra ${RFTK_LINALGEBRA_REPO_COMMIT}" >> "${TOOLS}/${RFTK_NAME}/SOURCES"
echo "geometry ${RFTK_GEOMETRY_REPO_COMMIT}" >> "${TOOLS}/${RFTK_NAME}/SOURCES"
