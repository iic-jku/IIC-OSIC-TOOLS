#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1 

git clone --filter=blob:none --no-checkout "${DOOR_REPO_URL}" "${DOOR_NAME}"
cd "${DOOR_NAME}" || exit 1
git checkout "${DOOR_REPO_COMMIT}"
mkdir -p build
cd build || exit 1
# CommonDB (CORE) is a private IHP repo we have no token for; build without it.
# Upstream renamed LibMan to DOOR, libman.pro is a deprecated shim for door.pro.
qmake6 CONFIG+=no_core ../door.pro
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
mkdir -p "${TOOLS}/${DOOR_NAME}/bin"
binary=""
for p in door release/door; do
    if [ -f "$p" ]; then
        binary="$p"
        break
    fi
done
if [ -z "$binary" ]; then
    echo "[ERROR] door binary not found after build" >&2
    ls -la
    exit 1
fi
mv "$binary" "${TOOLS}/${DOOR_NAME}/bin/door"
# Keep the pre-rename command name (LibMan) working
ln -s door "${TOOLS}/${DOOR_NAME}/bin/libman"

# Copy the capnp shared libraries that door was linked against so the
# binary can find them at runtime (capnp is built from source into
# capnp-install/ and is NOT part of the base runtime image).
CAPNP_LIB_DIR="/tmp/${DOOR_NAME}/capnp-install/lib"
mkdir -p "${TOOLS}/${DOOR_NAME}/lib"
if [ -d "${CAPNP_LIB_DIR}" ]; then
    find "${CAPNP_LIB_DIR}" \( -name "*.so" -o -name "*.so.*" \) -exec cp -a {} "${TOOLS}/${DOOR_NAME}/lib/" \;
fi

# Fix the binary RPATH so it resolves the capnp libraries relative to its
# own location (works regardless of the value of LD_LIBRARY_PATH).
apt-get -y install --no-install-recommends patchelf
patchelf --set-rpath '$ORIGIN/../lib' "${TOOLS}/${DOOR_NAME}/bin/door"

echo "${DOOR_NAME} ${DOOR_REPO_COMMIT}" > "${TOOLS}/${DOOR_NAME}/SOURCES"
