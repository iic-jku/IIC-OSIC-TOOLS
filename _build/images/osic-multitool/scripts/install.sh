#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

mkdir -p "$TOOLS" && cd "$TOOLS"
git clone --filter=blob:none "${OSIC_MULTITOOL_REPO_URL}" "${OSIC_MULTITOOL_NAME}"
cd "${OSIC_MULTITOOL_NAME}" || exit 1
git checkout "${OSIC_MULTITOOL_REPO_COMMIT}"

echo "${OSIC_MULTITOOL_NAME} ${OSIC_MULTITOOL_REPO_COMMIT}" > "${TOOLS}/${OSIC_MULTITOOL_NAME}/SOURCES"
