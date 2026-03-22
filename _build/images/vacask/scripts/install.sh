#!/bin/bash
set -euo pipefail
cd /tmp || exit 1

# Install custom libboost since stock libboost version is too old
BOOST_VERSION="1.88.0"
BOOST_DIR="boost_${BOOST_VERSION//./_}"
BOOST_ARCHIVE="${BOOST_DIR}.tar.gz"

wget -q "https://archives.boost.io/release/${BOOST_VERSION}/source/${BOOST_ARCHIVE}"
tar xf "${BOOST_ARCHIVE}"
cd "${BOOST_DIR}/tools/build"
./bootstrap.sh gcc
cd ../..
tools/build/b2 -j "$(nproc)" --with-filesystem --with-process --with-asio link=static toolset=gcc
cd ..

if [ -z "${VACASK_REPO_COMMIT:-}" ]; then
	# No specific ref -> shallow clone the default branch for speed
	git clone --filter=blob:none --depth 1 "${VACASK_REPO_URL}" "${VACASK_NAME}"
	cd "${VACASK_NAME}" || exit 1
else
	# When a specific ref (branch, tag, or commit) is given try a shallow fetch of that ref.
	# Use --no-checkout so we can fetch a single ref shallowly without downloading history.
	git clone --filter=blob:none --no-checkout "${VACASK_REPO_URL}" "${VACASK_NAME}"
	cd "${VACASK_NAME}" || exit 1

	# Try to fetch the exact ref shallowly. This usually works for branches and tags and
	# for commit SHAs on servers that allow fetching by SHA with depth.
	if git fetch --depth 1 origin "${VACASK_REPO_COMMIT}" >/dev/null 2>&1; then
		git checkout FETCH_HEAD
	else
		# Fallback: fetch all refs and tags, then checkout the requested ref (slower but reliable)
		git fetch --all --tags --prune
		git checkout "${VACASK_REPO_COMMIT}"
	fi
fi

mkdir -p build && cd build
cmake -G Ninja -S .. -B . -DCMAKE_BUILD_TYPE=Release -DOPENVAF_DIR="${TOOLS}/openvaf/bin" -DBoost_ROOT="/tmp/${BOOST_DIR}"
cmake --build . -j "$(nproc)"
cmake --install . --prefix "${TOOLS}/${VACASK_NAME}" --strip

# Remove openvaf-r binary since it's already provided by the openvaf image.
rm -f "${TOOLS}/${VACASK_NAME}/bin/openvaf-r"

echo "${VACASK_NAME} ${VACASK_REPO_COMMIT:-HEAD}" > "${TOOLS}/${VACASK_NAME}/SOURCES"

# Cleanup build artifacts
cd /tmp && rm -rf "${BOOST_DIR}" "${BOOST_ARCHIVE}" "${VACASK_NAME}"
