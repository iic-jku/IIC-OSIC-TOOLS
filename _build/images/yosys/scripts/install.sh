#!/bin/bash
set -e

# Build yosys
# -----------
cd /tmp || exit 1
git clone --filter=blob:none "${YOSYS_REPO_URL}" "${YOSYS_NAME}"
cd "${YOSYS_NAME}" || exit 1
git checkout "${YOSYS_REPO_COMMIT}"
git submodule update --init
make install -j"$(nproc)" PREFIX="${TOOLS}/${YOSYS_NAME}" CONFIG=gcc ENABLE_PYOSYS=1

export PATH=$PATH:${TOOLS}/${YOSYS_NAME}/bin

# Build yosys eqy
# ---------------
cd /tmp || exit 1
git clone --filter=blob:none "${YOSYS_EQY_REPO_URL}" "${YOSYS_EQY_NAME}"
cd "${YOSYS_EQY_NAME}" || exit 1
git checkout "${YOSYS_REPO_COMMIT}"
sed -i "s#^PREFIX.*#PREFIX=${TOOLS}/${YOSYS_NAME}#g" Makefile
make install -j"$(nproc)"

# Build yosys sby
# ---------------
cd /tmp || exit 1
git clone --filter=blob:none "${YOSYS_SBY_REPO_URL}" "${YOSYS_SBY_NAME}"
cd "${YOSYS_SBY_NAME}" || exit 1
git checkout "${YOSYS_REPO_COMMIT}"
sed -i "s#^PREFIX.*#PREFIX=${TOOLS}/${YOSYS_NAME}#g" Makefile
make install -j"$(nproc)" 

# Install yosys mcy
# -----------------
cd /tmp || exit 1
git clone --filter=blob:none "${YOSYS_MCY_REPO_URL}" "${YOSYS_MCY_NAME}"
cd "${YOSYS_MCY_NAME}" || exit 1
git checkout "${YOSYS_REPO_COMMIT}"
sed -i "s#^PREFIX.*#PREFIX=${TOOLS}/${YOSYS_NAME}#g" Makefile
make install -j"$(nproc)"

# Install solver for sby
# ----------------------
cd /tmp || exit 1
git clone --depth=1 https://github.com/SRI-CSL/yices2.git yices2
cd yices2 || exit 1
autoconf
./configure --prefix="${TOOLS}/${YOSYS_NAME}"
make -j"$(nproc)"
make install

# Make symlinks for binaries
# install wrapper for Yosys so that modules are loaded automatically
# see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/43
cd "$TOOLS/bin" || exit
ln -s ${TOOLS}/${YOSYS_NAME}/bin/* .
rm -f yosys
# shellcheck disable=SC2016
echo '#!/bin/bash
if [[ $1 == "-h" ]]; then
    exec -a "$0" "$TOOLS/yosys/bin/yosys" "$@"
else
    exec -a "$0" "$TOOLS/yosys/bin/yosys" -m ghdl -m slang "$@"
fi' > yosys
chmod +x yosys
