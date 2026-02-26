#!/bin/bash
set -e

mkdir -p "$TOOLS"
git clone --filter=blob:none "$NGSPYCE_REPO_URL" "${TOOLS}/$NGSPYCE_NAME"
cd "${TOOLS}/$NGSPYCE_NAME" || exit 1
git checkout "$NGSPYCE_REPO_COMMIT"

#python3 setup.py install
pip3 install . --prefix="${TOOLS}/$NGSPYCE_NAME" --no-cache-dir

# Remove .git directory to save space in final image
rm -rf "${TOOLS}/$NGSPYCE_NAME/.git"
