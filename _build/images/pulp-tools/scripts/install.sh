#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
mkdir -p "${TOOLS}/${PULP_NAME}/bin"
export RUSTUP_HOME=/tmp/rustup
export CARGO_HOME=/tmp/cargo
export PATH=$CARGO_HOME/bin:$PATH
rustup default stable

# Never let git block on a credential prompt: in a build container there is no
# tty, so a 401 from the server surfaces as the unhelpful "could not read
# Username for 'https://github.com': No such device or address".
export GIT_TERMINAL_PROMPT=0

# Reads the GIT_REPOSITORY/GIT_TAG of a FetchContent_Declare() block out of a
# CMakeLists, so the pins below always match what the upstream build would
# have fetched by itself.
cmake_fetch_pin () {
    # $1: CMakeLists to read, $2: FetchContent dependency name
    awk -v dep="$2" '
        /FetchContent_Declare\(/ { expect_name = 1; next }
        expect_name           { want = ($1 == dep); expect_name = 0; next }
        want && $1 == "GIT_REPOSITORY" { url = $2 }
        want && $1 == "GIT_TAG"        { tag = $2 }
        want && url != "" && tag != "" { print url, tag; exit }
    ' "$1"
}

# Clones a pinned source tree, retrying: GitHub occasionally refuses an
# anonymous clone while several tool images are building in parallel.
clone_pinned () {
    # $1: repository URL, $2: tag, $3: target directory
    attempts=5
    for attempt in $(seq 1 "${attempts}"); do
        rm -rf "$3"
        if git clone --depth 1 --branch "$2" "$1" "$3"; then
            return 0
        fi
        if [ "${attempt}" -lt "${attempts}" ]; then
            delay=$((attempt * 30))
            echo "[WARN] cloning $1 failed (attempt ${attempt}/${attempts}), retrying in ${delay}s" >&2
            sleep "${delay}"
        fi
    done
    echo "[ERROR] could not clone $1 at $2" >&2
    return 1
}

fetch_dep () {
    # $1: CMakeLists holding the pin, $2: dependency name, $3: target directory
    pin=$(cmake_fetch_pin "$1" "$2")
    url=${pin%% *}
    tag=${pin##* }
    if [ -z "${pin}" ] || [ "${url}" = "${tag}" ]; then
        echo "[ERROR] no FetchContent pin for '$2' in $1," >&2
        echo "[ERROR] the upstream build changed, this script needs an update." >&2
        exit 1
    fi
    echo "[INFO] Fetching $2 ${tag} for bender-slang"
    clone_pinned "${url}" "${tag}" "$3"
}

# Build Bender
# ------------
cd /tmp || exit 1
echo "[INFO] Building Bender"
git clone --filter=blob:none "${BENDER_REPO_URL}" bender
cd bender || exit 1
git checkout "${BENDER_REPO_COMMIT}"

# Bender's `slang` feature (on by default) builds the Slang C++ parser from the
# bender-slang crate. That crate's build script runs CMake, which git-clones
# slang, and then fmt and mimalloc from slang's own CMakeLists, via FetchContent
# while cargo is already running. When one of those clones is refused the whole
# image build dies with a credential prompt error, and CMake's three immediate
# retries are of no help. Clone the three sources here instead, where a refusal
# is legible and can be retried with a backoff, and hand them to the build
# script through the source-directory overrides it offers for offline builders.
BENDER_DEPS="/tmp/bender-deps"
fetch_dep crates/bender-slang/CMakeLists.txt slang "${BENDER_DEPS}/slang"
fetch_dep "${BENDER_DEPS}/slang/external/CMakeLists.txt" fmt "${BENDER_DEPS}/fmt"
fetch_dep "${BENDER_DEPS}/slang/external/CMakeLists.txt" mimalloc "${BENDER_DEPS}/mimalloc"
export SLANG_SRC_DIR="${BENDER_DEPS}/slang"
export FMT_SRC_DIR="${BENDER_DEPS}/fmt"
export MIMALLOC_SRC_DIR="${BENDER_DEPS}/mimalloc"

cargo update
cargo build --release -j"$(nproc)"
strip target/release/bender
cp target/release/bender "${TOOLS}/${PULP_NAME}/bin"
rm -rf "${BENDER_DEPS}"

# NOTE: Verible is provided by the dedicated 'verible' tool image (built from
# source, see images/verible). It was previously bundled here as a prebuilt
# binary, which shipped a second, older Verible that shadowed the standalone
# one on PATH. Removed to keep a single source of truth.

# Build SV2V
# ----------
cd /tmp || exit 1
echo "[INFO] Building SV2V"
# get Haskell stack first; force install into a PATH dir so the `stack`
# command is found below (the installer otherwise picks a dir that may not
# be on PATH, which made `stack install` fail with "command not found").
wget -qO- https://get.haskellstack.org/ | sh -s - -d /usr/local/bin
# now build SV2V using Haskell and Stack
git clone --filter=blob:none "${SV2V_REPO_URL}" sv2v
cd sv2v || exit 1
git checkout "${SV2V_REPO_COMMIT}"
stack install --install-ghc --local-bin-path bin --stack-root /tmp/stack
strip bin/sv2v
cp bin/sv2v "${TOOLS}/${PULP_NAME}/bin"

echo "bender ${BENDER_REPO_COMMIT}" > "${TOOLS}/${PULP_NAME}/SOURCES"
echo "sv2v ${SV2V_REPO_COMMIT}" >> "${TOOLS}/${PULP_NAME}/SOURCES"
