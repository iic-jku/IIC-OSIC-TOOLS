#!/bin/bash

REPO_COMMIT_SHORT=$(echo "$NGSPICE_REPO_COMMIT" | cut -c 1-10)

git clone --filter=blob:none "${NGSPICE_REPO_URL}" "${NGSPICE_NAME}"
cd "${NGSPICE_NAME}"
git checkout "${NGSPICE_REPO_COMMIT}"
./autogen.sh
#FIXME 2nd run of autogen needed
set -e
./autogen.sh

# Define common compile options
NGSPICE_COMPILE_OPTS=("--disable-debug" "--enable-openmp" "--with-x" "--with-readline=yes" "--enable-pss" "--enable-xspice" "--with-fftw3=yes" "--enable-osdi" "--enable-klu")

# Compile ngspice executable
./configure "${NGSPICE_COMPILE_OPTS[@]}" --prefix="${TOOLS}/${NGSPICE_NAME}/${REPO_COMMIT_SHORT}"
make -j"$(nproc)"
make install

# Cleanup between builds to prevent strange missing symbols in libngspice.
make distclean

# Now compile lib
./configure "${NGSPICE_COMPILE_OPTS[@]}" --with-ngshared --prefix="${TOOLS}/${NGSPICE_NAME}/${REPO_COMMIT_SHORT}"
make -j"$(nproc)"
make install

# Enable OSDI for IHP PDK
FNAME="${TOOLS}/${NGSPICE_NAME}/${REPO_COMMIT_SHORT}"/share/ngspice/scripts/spinit
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

    # Copy OSDI PSP model for IHP
    cp "$PDK_ROOT"/sg13g2/libs.tech/ngspice/openvaf/psp103_nqs.osdi "${TOOLS}"/"${NGSPICE_NAME}"/"${REPO_COMMIT_SHORT}"/lib/ngspice/psp103.osdi
fi

# Find OpenVAF version
OPENVAF_VERSION=$(ls "$TOOLS/$OPENVAF_NAME")

# Add BSIMCMG model, required for ASAP7
git clone --depth=1 https://github.com/dwarning/VA-Models.git vamodels
MODEL=bsimcmg
cd vamodels/code/$MODEL/vacode
"$TOOLS/$OPENVAF_NAME/$OPENVAF_VERSION"/bin/openvaf $MODEL.va
cp $MODEL.osdi "${TOOLS}"/"${NGSPICE_NAME}"/"${REPO_COMMIT_SHORT}"/lib/ngspice/$MODEL.osdi
echo "osdi ${TOOLS}/${NGSPICE_NAME}/${REPO_COMMIT_SHORT}/lib/ngspice/$MODEL.osdi" >> "$FNAME"
