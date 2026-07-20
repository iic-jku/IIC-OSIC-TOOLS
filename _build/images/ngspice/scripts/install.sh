#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${NGSPICE_REPO_URL}" "${NGSPICE_NAME}"
cd "${NGSPICE_NAME}" || exit 1
git checkout "${NGSPICE_REPO_COMMIT}"
./autogen.sh
# 2nd run of autogen needed
./autogen.sh

# define common compile options
NGSPICE_COMPILE_OPTS=("--disable-debug" "--enable-openmp" "--with-x" "--with-readline=yes" "--enable-pss" "--enable-xspice" "--with-fftw3=yes" "--enable-osdi" "--enable-klu")

# Build the shared library (libngspice) FIRST.
# NOTE: with --with-ngshared and --disable-debug, ngspice's configure appends
# -fvisibility=hidden to the global CFLAGS. This also hides the Cosim_setup
# entry point in the Icarus Verilog co-simulation bridge (ivlng.so), which
# breaks mixed-signal simulation ("undefined symbol: Cosim_setup", see #287).
# Therefore the executable (built with default visibility) must be installed
# LAST so that its correctly-exported ivlng.so is the one that ends up in the
# image.
./configure "${NGSPICE_COMPILE_OPTS[@]}" --with-ngshared --prefix="${TOOLS}/${NGSPICE_NAME}"
make -j"$(nproc)"
make install

# cleanup between builds to prevent strange missing symbols in libngspice
make distclean

# now compile the ngspice executable (installed last, see note above)
./configure "${NGSPICE_COMPILE_OPTS[@]}" --prefix="${TOOLS}/${NGSPICE_NAME}"
make -j"$(nproc)"
make install

# enable OSDI for IHP PDK
_add_model() {
    if [ -f "$PDK_ROOT/ihp-sg13g2/libs.tech/ngspice/osdi/$1" ]; then
        cp "$PDK_ROOT/ihp-sg13g2/libs.tech/ngspice/osdi/$1" "${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$1"
        echo "osdi ${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$1" >> "$2"
    fi
}
FNAME="${TOOLS}/${NGSPICE_NAME}/share/ngspice/scripts/spinit"

# enable OSDI for IHP PDK
_add_model psp103_nqs.osdi "$FNAME"
_add_model r3_cmc.osdi "$FNAME"

# add BSIMCMG model, required for ASAP7
git clone --depth=1 https://github.com/dwarning/VA-Models.git vamodels
MODEL=bsimcmg
cd vamodels/code/$MODEL/vacode || exit 1
"$TOOLS/openvaf/bin/openvaf" --target_cpu generic "$MODEL.va"
cp "$MODEL.osdi" "${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi"
echo "osdi ${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi" >> "$FNAME"

echo "${NGSPICE_NAME} ${NGSPICE_REPO_COMMIT}" > "${TOOLS}/${NGSPICE_NAME}/SOURCES"
