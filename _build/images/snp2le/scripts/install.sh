#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# snp2le is a pure-Python tool (PySide6 GUI + CLI). All Python dependencies
# (PySide6, scikit-rf, schemdraw, matplotlib, numpy, scipy) are already
# provided by the base image, so we only need to fetch the sources and expose
# launcher wrappers on PATH.

mkdir -p "$TOOLS" && cd "$TOOLS"
git clone --filter=blob:none "${SNP2LE_REPO_URL}" "${SNP2LE_NAME}"
cd "${SNP2LE_NAME}" || exit 1
git checkout "${SNP2LE_REPO_COMMIT}"

# Create wrappers in bin/ so install_links.sh symlinks them onto PATH.
mkdir -p "${TOOLS}/${SNP2LE_NAME}/bin"

# The Python application lives in the converter/ subdirectory and uses bare
# imports (`from gui... import`, `from core... import`), so the wrappers must
# run from converter/ for the package root to resolve.

# GUI launcher (PySide6).
# shellcheck disable=SC2016
echo '#!/bin/bash
cd "${TOOLS}/snp2le/converter" && exec python3 app.py "$@"' > "${TOOLS}/${SNP2LE_NAME}/bin/snp2le"
chmod +x "${TOOLS}/${SNP2LE_NAME}/bin/snp2le"

# Command-line interface (for Makefiles / batch conversion).
# shellcheck disable=SC2016
echo '#!/bin/bash
cd "${TOOLS}/snp2le/converter" && exec python3 cli.py "$@"' > "${TOOLS}/${SNP2LE_NAME}/bin/snp2le-cli"
chmod +x "${TOOLS}/${SNP2LE_NAME}/bin/snp2le-cli"

echo "${SNP2LE_NAME} ${SNP2LE_REPO_COMMIT}" > "${TOOLS}/${SNP2LE_NAME}/SOURCES"
