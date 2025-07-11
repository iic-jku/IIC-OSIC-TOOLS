#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${NGSPICE_REPO_URL}" "${NGSPICE_NAME}"
cd "${NGSPICE_NAME}"
git checkout "${NGSPICE_REPO_COMMIT}"
./autogen.sh
# 2nd run of autogen needed
./autogen.sh

# define common compile options
NGSPICE_VERSION=${NGSPICE_REPO_COMMIT##*-}
if [ "$NGSPICE_VERSION" -lt 43 ]; then
    echo "[INFO] We are building ngspice version 42 or lower."
    NGSPICE_COMPILE_OPTS=("--disable-debug" "--enable-openmp" "--with-x" "--with-readline=yes" "--enable-pss" "--enable-xspice" "--with-fftw3=yes" "--enable-osdi" "--enable-klu")
else
    echo "[INFO] We are building ngspice version 43 or higher."
    NGSPICE_COMPILE_OPTS=("--with-x" "--enable-pss" "--with-fftw3=yes" )
fi

# compile ngspice executable
./configure "${NGSPICE_COMPILE_OPTS[@]}" --prefix="${TOOLS}/${NGSPICE_NAME}"
make -j"$(nproc)"
make install

# cleanup between builds to prevent strange missing symbols in libngspice
make distclean

# now compile lib
./configure "${NGSPICE_COMPILE_OPTS[@]}" --with-ngshared --prefix="${TOOLS}/${NGSPICE_NAME}"
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
"$TOOLS/openvaf/bin/openvaf" $MODEL.va
cp $MODEL.osdi "${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi"
echo "osdi ${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi" >> "$FNAME"
