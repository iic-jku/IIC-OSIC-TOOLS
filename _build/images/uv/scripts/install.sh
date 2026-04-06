#!/bin/bash
set -e
cd /tmp || exit 1

if [ "$(uname -m)" = "aarch64" ]; then
    ARCH="aarch64"
else
    ARCH="x86_64"
fi

EXTRACTED_DIR="uv-${ARCH}-unknown-linux-gnu"
FILE="${EXTRACTED_DIR}.tar.gz"
URL="${UV_REPO_URL}/releases/download/${UV_VERSION}/${FILE}"

wget --no-verbose "${URL}" || { echo "[ERROR] Failed to download uv ${UV_VERSION}"; exit 1; }
tar xfz "${FILE}"
rm -f "${FILE}"

mkdir -p "${TOOLS}/${UV_NAME}/bin"
cp "${EXTRACTED_DIR}/uv" "${TOOLS}/${UV_NAME}/bin/"
cp "${EXTRACTED_DIR}/uvx" "${TOOLS}/${UV_NAME}/bin/"

echo "${UV_NAME} ${UV_VERSION}" > "${TOOLS}/${UV_NAME}/SOURCES"
