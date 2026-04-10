#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

# Install Bazel (build-time only, needed to compile Verible)
BAZEL_VERSION="7.6.0"
echo "[INFO] Installing Bazel ${BAZEL_VERSION}"
if [ "$(arch)" == "aarch64" ]; then
    BAZEL_ARCH="arm64"
else
    BAZEL_ARCH="x86_64"
fi
BAZEL_BIN="/usr/local/bin/bazel"
wget --no-verbose "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-${BAZEL_ARCH}" -O "${BAZEL_BIN}"
chmod +x "${BAZEL_BIN}"
bazel --version

# Clone and build Verible from source
echo "[INFO] Building Verible ${VERIBLE_REPO_COMMIT}"
git clone --filter=blob:none "${VERIBLE_REPO_URL}" "${VERIBLE_NAME}"
cd "${VERIBLE_NAME}" || exit 1
git checkout "${VERIBLE_REPO_COMMIT}"
bazel build -c opt :install-binaries
mkdir -p "${TOOLS}/${VERIBLE_NAME}/bin"
bash .github/bin/simple-install.sh "${TOOLS}/${VERIBLE_NAME}/bin"
strip "${TOOLS}/${VERIBLE_NAME}/bin"/*

echo "${VERIBLE_NAME} ${VERIBLE_REPO_COMMIT}" > "${TOOLS}/${VERIBLE_NAME}/SOURCES"
