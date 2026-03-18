#!/bin/bash

set -e
mkdir -p "${TOOLS}/${RFTK_NAME}"

# FastHenry2 for inductance extractions
# -------------------------------------
cd /tmp || exit 1
git clone --filter=blob:none "${RFTK_FASTHENRY_REPO_URL}" "${RFTK_NAME}_fh"
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
git clone --filter=blob:none "${RFTK_FASTERCAP_REPO_URL}" "${RFTK_NAME}_fc"
# get additional libs (LinAlgebra and Geometry)
# FIXME check if lib versions fit to FasterCap version (last done 2023-05-20)
git clone https://github.com/ediloren/LinAlgebra.git
cd LinAlgebra || exit 1
git checkout 627132d70bfd7eadd727f930286938a5a01d9914
cd ..
git clone --filter=blob:none https://github.com/ediloren/Geometry.git
cd Geometry || exit 1
git checkout de03ffebfd5013b96102bd60f71c8fe8b73870e2
cd ..
# now build FasterCap
cd "${RFTK_NAME}_fc" || exit 1
git checkout "${RFTK_FASTERCAP_REPO_COMMIT}"

# patch FasterCap cmake (fix thanks to Ali Olyanasab) 
sed -i '3 i add_definitions(-w)' CMakeLists.txt
# patch FasterCap cmake for 24.04 LTS (thanks to ChatGPT)
sed -i 's/--version=3\.0/--version=3\.2/' CMakeLists.txt

mkdir build && cd build
#cmake -G"CodeBlocks - Unix Makefiles" -DCMAKE_BUILD_TYPE=Release ..
cmake -G"Unix Makefiles"  -DCMAKE_BUILD_TYPE=Release -DFASTFIELDSOLVERS_HEADLESS=ON ..
make -j"$(nproc)" all
cp FasterCap "${TOOLS}/${RFTK_NAME}/bin"
ln -s "${TOOLS}/${RFTK_NAME}/bin/FasterCap" "${TOOLS}/${RFTK_NAME}/bin/fastercap"
ln -s "${TOOLS}/${RFTK_NAME}/bin/FasterCap" "${TOOLS}/${RFTK_NAME}/bin/fastcap"
