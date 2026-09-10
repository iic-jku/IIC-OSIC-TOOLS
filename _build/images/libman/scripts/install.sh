#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1 

git clone --filter=blob:none "${LIBMAN_REPO_URL}" "${LIBMAN_NAME}"
cd "${LIBMAN_NAME}" || exit 1
git checkout "${LIBMAN_REPO_COMMIT}"
mkdir -p build
cd build || exit 1
# CommonDB (CORE) is a private IHP repo we have no token for; build without it.
qmake6 CONFIG+=no_core ../libman.pro
export CAPNP_SKIP_CHECK=1
make -j1 capnp_install
# This target clones the LStream schemas from codeberg.org, which is markedly
# less reliable than GitHub (seen in the wild: HTTP 502, and HTTP 504 after a
# 30s hang). The upstream script is idempotent -- it skips the clone once
# .deps/lstream/.git exists and re-checks the target revision -- so retrying is
# safe. Codeberg outages have outlasted a two-minute window, so back off over
# roughly ten minutes before giving up on an otherwise hour-long build.
LSTREAM_ATTEMPTS=5
lstream_done=0
for attempt in $(seq 1 "${LSTREAM_ATTEMPTS}"); do
    if make -j1 lstream_schemas; then
        lstream_done=1
        break
    fi
    if [ "$attempt" -lt "${LSTREAM_ATTEMPTS}" ]; then
        delay=$((attempt * 30))
        echo "[WARN] lstream_schemas failed (attempt ${attempt}/${LSTREAM_ATTEMPTS}), retrying in ${delay}s" >&2
        sleep "${delay}"
    fi
done
if [ "$lstream_done" -ne 1 ]; then
    echo "[ERROR] lstream_schemas failed after ${LSTREAM_ATTEMPTS} attempts;" >&2
    echo "[ERROR] check https://status.codeberg.org and rerun the build." >&2
    exit 1
fi
unset CAPNP_SKIP_CHECK
make -j"$(nproc)"
mkdir -p "${TOOLS}/${LIBMAN_NAME}/bin"
# binary may be named libman or LibMan depending on Qt version
binary=""
for p in libman LibMan release/libman release/LibMan; do
    if [ -f "$p" ]; then
        binary="$p"
        break
    fi
done
if [ -z "$binary" ]; then
    echo "ERROR: libman binary not found after build" >&2
    ls -la
    exit 1
fi
mv "$binary" "${TOOLS}/${LIBMAN_NAME}/bin/libman"

# Copy the capnp shared libraries that libman was linked against so the
# binary can find them at runtime (capnp is built from source into
# capnp-install/ and is NOT part of the base runtime image).
CAPNP_LIB_DIR="/tmp/${LIBMAN_NAME}/capnp-install/lib"
mkdir -p "${TOOLS}/${LIBMAN_NAME}/lib"
if [ -d "${CAPNP_LIB_DIR}" ]; then
    find "${CAPNP_LIB_DIR}" \( -name "*.so" -o -name "*.so.*" \) -exec cp -a {} "${TOOLS}/${LIBMAN_NAME}/lib/" \;
fi

# Fix the binary RPATH so it resolves the capnp libraries relative to its
# own location (works regardless of the value of LD_LIBRARY_PATH).
apt-get -y install --no-install-recommends patchelf
patchelf --set-rpath '$ORIGIN/../lib' "${TOOLS}/${LIBMAN_NAME}/bin/libman"

echo "${LIBMAN_NAME} ${LIBMAN_REPO_COMMIT}" > "${TOOLS}/${LIBMAN_NAME}/SOURCES"
