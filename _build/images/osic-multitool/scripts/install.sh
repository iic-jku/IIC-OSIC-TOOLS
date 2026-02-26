#!/bin/bash
set -e

mkdir -p "$TOOLS" && cd "$TOOLS"
git clone --filter=blob:none "${OSIC_MULTITOOL_REPO_URL}" "${OSIC_MULTITOOL_NAME}"
cd "${OSIC_MULTITOOL_NAME}" || exit 1
git checkout "${OSIC_MULTITOOL_REPO_COMMIT}"
