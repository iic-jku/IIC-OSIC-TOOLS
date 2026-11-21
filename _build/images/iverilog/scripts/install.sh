#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${IVERILOG_REPO_URL}" "${IVERILOG_NAME}"
cd "${IVERILOG_NAME}" || exit 1
git checkout "${IVERILOG_REPO_COMMIT}"

# Since steveicarus/iverilog PR 1743 ($recrem) and PR 1745 ($setuphold),
# elaboration with -gspecify rejects timing checks with delayed signals, which
# the IHP and sky130 standard cells use, so every SDF gate-level simulation of
# them fails. The patch restores the behavior before these PRs for such
# checks: a warning, no runtime check, and the delayed signals copied from the
# originals. A runtime check is no option, the SDF annotation rejects the
# negative limits that STA writes for the cells. The SDF annotation of a
# timing check without a match or with a negative limit is a warning instead of
# an error, as such limits were ignored before. Reported as
# steveicarus/iverilog#1871, test 52 checks it. Drop once upstream accepts
# these checks and negative limits.
git apply /images/iverilog/patches/timing-check-delayed-signals.patch

chmod +x autoconf.sh
./autoconf.sh
./configure --prefix="${TOOLS}/${IVERILOG_NAME}" --enable-libvvp
make -j"$(nproc)"
make install

echo "${IVERILOG_NAME} ${IVERILOG_REPO_COMMIT}" > "${TOOLS}/${IVERILOG_NAME}/SOURCES"
