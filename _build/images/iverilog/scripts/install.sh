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
# elaboration with -gspecify rejects timing checks with timestamp/timecheck
# conditions, which the sky130 standard cells use, so every SDF gate-level
# simulation of them fails. PR 1875 (fix for steveicarus/iverilog#1871)
# accepts delayed signals and clamps negative SDF limits, but still rejects
# these conditions. The patch makes them a warning with no runtime check and
# the delayed signals copied from the originals, as before PR 1743. The SDF
# annotation of such an unchecked timing check is a warning instead of an
# error. Reported in steveicarus/iverilog#1871 (comment of 2026-11-22), test
# 66 checks it. Drop once upstream accepts these conditions.
git apply /images/iverilog/patches/timing-check-delayed-signals.patch

chmod +x autoconf.sh
./autoconf.sh
./configure --prefix="${TOOLS}/${IVERILOG_NAME}" --enable-libvvp
make -j"$(nproc)"
make install

echo "${IVERILOG_NAME} ${IVERILOG_REPO_COMMIT}" > "${TOOLS}/${IVERILOG_NAME}/SOURCES"
