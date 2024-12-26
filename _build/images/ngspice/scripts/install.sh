#!/bin/bash
cd /tmp || exit 1

git clone --filter=blob:none "${NGSPICE_REPO_URL}" "${NGSPICE_NAME}"
cd "${NGSPICE_NAME}"
git checkout "${NGSPICE_REPO_COMMIT}"
./autogen.sh
# 2nd run of autogen needed
set -e
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
FNAME="${TOOLS}/${NGSPICE_NAME}/share/ngspice/scripts/spinit"
if [ -f "$PDK_ROOT"/sg13g2/libs.tech/ngspice/openvaf/psp103_nqs.osdi ]; then
    cp "$FNAME" "$FNAME".bak
    sed -i "s/unset osdi_enabled/* unset osdi_enabled/g" "$FNAME"

    sed -i "/asmhemt.osdi/s/^/#/" "$FNAME"
    sed -i "/bjt504t.osdi/s/^/#/" "$FNAME"
    sed -i "/BSIMBULK107.osdi/s/^/#/" "$FNAME"
    sed -i "/BSIMCMG.osdi/s/^/#/" "$FNAME"
    sed -i "/HICUMl0-2.0.osdi/s/^/#/" "$FNAME"
    sed -i "/r2_cmc.osdi/s/^/#/" "$FNAME"
    sed -i "/vbic_4T_et_cf.osdi/s/^/#/" "$FNAME"

    # copy OSDI PSP model for IHP
    cp "$PDK_ROOT/sg13g2/libs.tech/ngspice/openvaf/psp103_nqs.osdi" "${TOOLS}/${NGSPICE_NAME}/lib/ngspice/psp103_nqs.osdi"
fi

# add BSIMCMG model, required for ASAP7
git clone --depth=1 https://github.com/dwarning/VA-Models.git vamodels
MODEL=bsimcmg
cd vamodels/code/$MODEL/vacode || exit 1
"$TOOLS/$OPENVAF_NAME/bin/openvaf" $MODEL.va
cp $MODEL.osdi "${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi"
echo "osdi ${TOOLS}/${NGSPICE_NAME}/lib/ngspice/$MODEL.osdi" >> "$FNAME"
