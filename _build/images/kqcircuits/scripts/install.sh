#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none --no-checkout "${KQCIRCUITS_REPO_URL}" "${KQCIRCUITS_NAME}"
cd "${KQCIRCUITS_NAME}" || exit 1
git checkout "${KQCIRCUITS_REPO_COMMIT}"

# Save the Git-derived version before patching and omit Git history from the image.
# setuptools-git-versioning reads PKG-INFO when registering the editable install later.
pip3 wheel --no-deps --no-cache-dir ./klayout_package/python --wheel-dir /tmp/kqc-wheels
cp klayout_package/python/kqcircuits.egg-info/PKG-INFO klayout_package/python/PKG-INFO
rm -rf klayout_package/python/build klayout_package/python/kqcircuits.egg-info /tmp/kqc-wheels

# Patch dependencies for the shared environment and set a writable output default.
# Each patch records whether it is waiting for upstream or is image-specific.
for patchfile in /images/kqcircuits/patches/*.patch; do
    patch --batch --fuzz=0 -p1 < "$patchfile"
done

# Keep the source layout for example discovery and copied simulation support scripts.
mkdir -p "${TOOLS}/${KQCIRCUITS_NAME}/klayout_package"
cp -a klayout_package/python "${TOOLS}/${KQCIRCUITS_NAME}/klayout_package/"
cp LICENSE "${TOOLS}/${KQCIRCUITS_NAME}/"
echo "${KQCIRCUITS_NAME} ${KQCIRCUITS_REPO_COMMIT}" > "${TOOLS}/${KQCIRCUITS_NAME}/SOURCES"
cd /tmp || exit 1
rm -rf "${KQCIRCUITS_NAME}"
