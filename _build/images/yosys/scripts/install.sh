#!/bin/bash
set -e

# Build yosys
# -----------
cd /tmp || exit 1
git clone --filter=blob:none "${YOSYS_REPO_URL}" "${YOSYS_NAME}"
cd "${YOSYS_NAME}" || exit 1
git checkout "${YOSYS_REPO_COMMIT}"
git submodule update --init
make install -j"$(nproc)" PREFIX="${TOOLS}/${YOSYS_NAME}" CONFIG=gcc

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
