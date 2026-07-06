#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${MAGIC_REPO_URL}" "${MAGIC_NAME}"
cd "${MAGIC_NAME}" || exit 1
git checkout "${MAGIC_REPO_COMMIT}"

# Apply local patches (if any). See images/magic/patches/.
# Currently fixes a SIGSEGV in `-dnull` batch extraction/DEF-read where
# Tk_RestrictEvents() is called although Tk is never initialized (crashes on
# aarch64). Upstream: rtimothyedwards/magic. 
# FIXME Drop once merged upstream.
PATCH_DIR="/images/${MAGIC_NAME}/patches"
if [ -d "${PATCH_DIR}" ]; then
    for p in "${PATCH_DIR}"/*.patch; do
        [ -e "$p" ] || continue
        echo "[install.sh] applying patch $(basename "$p")"
        git apply --verbose "$p"
    done
fi

./configure --prefix="${TOOLS}/${MAGIC_NAME}"
make database/database.h
make -j"$(nproc)"
make install

echo "$MAGIC_NAME $MAGIC_REPO_COMMIT" > "${TOOLS}/${MAGIC_NAME}/SOURCES"
