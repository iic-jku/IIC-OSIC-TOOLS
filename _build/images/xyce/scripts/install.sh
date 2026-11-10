#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${XYCE_REPO_URL}" "${XYCE_NAME}"
cd "${XYCE_NAME}" || exit 1
git checkout "${XYCE_REPO_COMMIT}"
./bootstrap

git clone --filter=blob:none --no-checkout "${XYCE_TRILINOS_REPO_URL}" "${XYCE_TRILINOS_NAME}"
cd "${XYCE_TRILINOS_NAME}" || exit 1
git checkout "${XYCE_TRILINOS_REPO_COMMIT}"
mkdir -p parallel_build && cd parallel_build
# CMake 4 rejects cmake_minimum_required below 3.5 in Trilinos. The environment
# variable also reaches the nested CMake runs. Drop it once upstream raises it.
export CMAKE_POLICY_VERSION_MINIMUM=3.5
cp /images/xyce/scripts/trilinos.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh
make -j"$(nproc)"
make install

cd /tmp/"${XYCE_NAME}" || exit 1
mkdir -p parallel_build && cd parallel_build
cp /images/xyce/scripts/xyce.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh

# build models
cd src/DeviceModelPKG/ADMS
make -j"$(nproc)"
cd ../../..

# user_plugin runs admsXml on rlc.va from two rules, and the two-target rule
# can run once per target. Parallel admsXml runs share the preprocessed
# .rlc.va.adms in the build dir and truncate it for each other ("rlc.va:
# during lexical analysis syntax error at line 0"). Generate these sources
# serially first. Drop with the move off autotools (removed upstream in
# Xyce 23c80684, after Release-7.10.0).
make -C user_plugin -j1 N_DEV_ADMSrlc.C N_DEV_ADMSrlc_bootstrap.C

# build Xyce
make -j"$(nproc)"
make install

# Remove static link libraries (~220 MB); only needed when linking new
# programs against Xyce, which is done in the build stage, not at runtime
find "${TOOLS}/${XYCE_NAME}" -type f -name "*.a" -delete

echo "${XYCE_NAME} ${XYCE_REPO_COMMIT}" > "${TOOLS}/${XYCE_NAME}/SOURCES"
echo "${XYCE_TRILINOS_NAME} ${XYCE_TRILINOS_REPO_COMMIT}" >> "${TOOLS}/${XYCE_NAME}/SOURCES"
