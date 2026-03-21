#!/bin/bash
set -e
cd /tmp || exit 1

# Determine architecture for Bazel binary download
ARCH=$(uname -m)
if [ "${ARCH}" = "x86_64" ]; then
    BAZEL_ARCH="x86_64"
elif [ "${ARCH}" = "aarch64" ]; then
    BAZEL_ARCH="arm64"
else
    echo "[ERROR] Unsupported architecture: ${ARCH}"
    exit 1
fi

# Install Bazel (required to build verible)
BAZEL_VERSION="7.6.1"
BAZEL_EXEC="/usr/local/bin/bazel"
wget "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-${BAZEL_ARCH}" -O "${BAZEL_EXEC}"
chmod +x "${BAZEL_EXEC}"
bazel --version

# Install Java (required by Bazel)
apt-get install -y --no-install-recommends default-jdk-headless

# Clone and build verible from source
git clone --filter=blob:none "${VERIBLE_REPO_URL}" "${VERIBLE_NAME}"
cd "${VERIBLE_NAME}" || exit 1
git checkout "${VERIBLE_REPO_COMMIT}"

# Build all verible tools
bazel build -c opt --noshow_progress --verbose_failures --jobs="$(nproc)" :install-binaries

# Install binaries
mkdir -p "${TOOLS}/${VERIBLE_NAME}/bin"
.github/bin/simple-install.sh "${TOOLS}/${VERIBLE_NAME}/bin"

# Strip binaries to reduce size
find "${TOOLS}/${VERIBLE_NAME}/bin" -type f -executable -exec strip {} \; 2>/dev/null || true

echo "${VERIBLE_NAME} ${VERIBLE_REPO_COMMIT}" > "${TOOLS}/${VERIBLE_NAME}/SOURCES"

# Cleanup Bazel cache to reduce layer size
bazel clean --expunge 2>/dev/null || true
rm -rf ~/.cache/bazel /root/.cache/bazel
