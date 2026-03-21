#!/bin/bash
set -e
cd /tmp || exit 1

# Map architecture to verible release naming convention
ARCH=$(uname -m)
if [ "${ARCH}" = "x86_64" ]; then
    VERIBLE_ARCH="x86_64"
elif [ "${ARCH}" = "aarch64" ]; then
    VERIBLE_ARCH="arm64"
else
    echo "[ERROR] Unsupported architecture: ${ARCH}"
    exit 1
fi

VERIBLE_TARBALL="verible-${VERIBLE_REPO_COMMIT}-linux-static-${VERIBLE_ARCH}.tar.gz"
VERIBLE_URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_REPO_COMMIT}/${VERIBLE_TARBALL}"

wget "${VERIBLE_URL}" -O "${VERIBLE_TARBALL}"
tar -xf "${VERIBLE_TARBALL}"

mkdir -p "${TOOLS}/${VERIBLE_NAME}/bin"
cp "verible-${VERIBLE_REPO_COMMIT}/bin/"* "${TOOLS}/${VERIBLE_NAME}/bin/"

echo "${VERIBLE_NAME} ${VERIBLE_REPO_COMMIT}" > "${TOOLS}/${VERIBLE_NAME}/SOURCES"
