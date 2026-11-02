#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# PyOPUS requires python3-cvxopt from APT (otherwise the build fails on aarch64).
mkdir -p "$TOOLS"
cd /tmp || exit 1
# No --depth: setuptools_scm derives the package version from the nearest tag.
git clone --filter=blob:none --no-checkout "${PYOPUS_REPO_URL}" "${PYOPUS_NAME}"
cd "${PYOPUS_NAME}" || exit 1
git checkout "${PYOPUS_REPO_COMMIT}"
# Release that the pinned commit descends from (v0.12 -> 0.12), names the doc download below
PYOPUS_RELEASE=$(git describe --tags --abbrev=0 --match 'v[0-9]*')
PYOPUS_RELEASE=${PYOPUS_RELEASE#v}
pip3 install . --prefix="$TOOLS/$PYOPUS_NAME" --no-cache-dir
ln -s "$TOOLS/$PYOPUS_NAME/local/bin" "$TOOLS/$PYOPUS_NAME/bin"

# PyOPUS ports itself to PySide6 since 92a5ab0 and pulls in the full PySide6
# (Addons, WebEngine, Pdf). The image already ships PySide6 through
# install_eda.sh, trimmed to PySide6-Essentials, which covers the QtCore,
# QtGui and QtWidgets that PyOPUS imports. Drop the duplicate from the prefix,
# which PYTHONPATH would put ahead of the image's copy, together with its
# pyside6-* entry points, which install_links.sh would link into $TOOLS/bin.
PYOPUS_SITE=$(find "$TOOLS/$PYOPUS_NAME" -type d -name dist-packages | head -1)
[ -n "$PYOPUS_SITE" ] || { echo "[ERROR] PyOPUS dist-packages not found"; exit 1; }
echo "[INFO] Removing the PySide6 copy pulled in by PyOPUS"
rm -rf "$PYOPUS_SITE"/PySide6* "$PYOPUS_SITE"/pyside6* "$PYOPUS_SITE"/shiboken6*
rm -f "$TOOLS/$PYOPUS_NAME"/local/bin/pyside6-* "$TOOLS/$PYOPUS_NAME"/local/bin/shiboken6*

# Install examples from the pinned commit
mv /tmp/"${PYOPUS_NAME}"/demo "$TOOLS/$PYOPUS_NAME/demo"
cd /tmp && rm -rf "${PYOPUS_NAME}"

# The repo holds only the Sphinx sources of the docs (autodoc, needs the
# sphinx_rtd_theme and graphviz). The HTML build is published per release only,
# so install the one of the release the pinned commit descends from.
PYOPUS_DOC_URL="https://fides.fe.uni-lj.si/pyopus/download"
wget --no-verbose "$PYOPUS_DOC_URL/$PYOPUS_RELEASE/PyOPUS-$PYOPUS_RELEASE-doc-demo.tar.gz"
tar xfz "PyOPUS-$PYOPUS_RELEASE-doc-demo.tar.gz"
mv "PyOPUS-$PYOPUS_RELEASE/docsrc/_build/html" "$TOOLS/$PYOPUS_NAME/doc"
rm -rf "PyOPUS-$PYOPUS_RELEASE" "PyOPUS-$PYOPUS_RELEASE-doc-demo.tar.gz"

echo "${PYOPUS_NAME} ${PYOPUS_REPO_COMMIT}" > "${TOOLS}/${PYOPUS_NAME}/SOURCES"
