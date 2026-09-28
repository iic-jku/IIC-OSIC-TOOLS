#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${OPENCDC_REPO_URL}" "${OPENCDC_NAME}"
cd "${OPENCDC_NAME}" || exit 1
git checkout "${OPENCDC_REPO_COMMIT}"

# Build against the slang install from the slang tool image instead of the
# slang release that CMakeLists.txt fetches: in ALWAYS mode,
# FetchContent_MakeAvailable() tries find_package() first and only fetches
# what is not found (nlohmann_json; yaml-cpp comes from the system).
# CMAKE_REQUIRE_FIND_PACKAGE_slang makes a missing slang fail the build
# instead of silently falling back to fetching it.
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS \
    -DCMAKE_REQUIRE_FIND_PACKAGE_slang=ON \
    -DCMAKE_PREFIX_PATH="${TOOLS}/slang"
cmake --build build --target opencdc -j"$(nproc)"
install -D -m 755 -s build/src/opencdc "${TOOLS}/${OPENCDC_NAME}/bin/opencdc"

echo "${OPENCDC_NAME} ${OPENCDC_REPO_COMMIT}" > "${TOOLS}/${OPENCDC_NAME}/SOURCES"

# Cleanup
cd /tmp && rm -rf "${OPENCDC_NAME}"
