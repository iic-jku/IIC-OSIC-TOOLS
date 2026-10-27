#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${VERILATOR_REPO_URL}" "${VERILATOR_NAME}"
cd "${VERILATOR_NAME}" || exit 1
git checkout "${VERILATOR_REPO_COMMIT}"
autoconf
unset VERILATOR_ROOT
./configure --prefix="${TOOLS}/${VERILATOR_NAME}"
make -j"$(nproc)"
make install
# and we strip the binaries to reduce size
find "${TOOLS}/${VERILATOR_NAME}" -type f -executable -exec strip {} \;

# Ship the UVM library that Verilator is tested against (single-file packages
# with and without DPI, plus the DPI C sources). It sits in the test tree
# only, `make install` does not copy it.
UVM_VERSION="v2020_3_2"
UVM_DIR="${TOOLS}/${VERILATOR_NAME}/share/uvm"
mkdir -p "${UVM_DIR}/dpi"
cp "test_regress/t/uvm/uvm_pkg_all_${UVM_VERSION}_dpi.svh" "${UVM_DIR}/uvm_pkg_dpi.svh"
cp "test_regress/t/uvm/uvm_pkg_all_${UVM_VERSION}_nodpi.svh" "${UVM_DIR}/uvm_pkg_nodpi.svh"
cp "test_regress/t/uvm/${UVM_VERSION}/dpi/"*.{c,cc,h,svh} "${UVM_DIR}/dpi/"
# The packages define the UVM macros already. The stub keeps the usual
# `include "uvm_macros.svh"` of a test bench resolving with +incdir+$UVM_HOME.
echo "// UVM macros are defined in uvm_pkg_dpi.svh and uvm_pkg_nodpi.svh" > "${UVM_DIR}/uvm_macros.svh"
echo "${UVM_VERSION}" > "${UVM_DIR}/VERSION"
cat > "${UVM_DIR}/README.md" << EOF
# UVM for Verilator

UVM ${UVM_VERSION} as packed by Verilator ${VERILATOR_REPO_COMMIT} for its own regression tests (\`test_regress/t/uvm\`), Apache-2.0. Known limitations of the Verilator UVM support: https://github.com/verilator/verilator/issues/1538

Without DPI (no \`uvm_hdl_*\` backdoor access, only glob patterns in \`uvm_config_db\` lookups):

    verilator --binary -j 0 +incdir+\$UVM_HOME \$UVM_HOME/uvm_pkg_nodpi.svh tb.sv

With DPI:

    verilator --binary -j 0 --vpi +incdir+\$UVM_HOME \$UVM_HOME/uvm_pkg_dpi.svh \$UVM_HOME/dpi/uvm_dpi.cc tb.sv

The packages define the UVM macros, so \`uvm_macros.svh\` here is an empty stub. Add \`+UVM_NO_RELNOTES\` to the simulation command to drop the release notes banner.
EOF

echo "${VERILATOR_NAME} ${VERILATOR_REPO_COMMIT}" > "${TOOLS}/${VERILATOR_NAME}/SOURCES"
