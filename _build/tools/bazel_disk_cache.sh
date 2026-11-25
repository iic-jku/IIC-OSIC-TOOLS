#!/bin/bash
# ========================================================================
# Carry the Bazel disk cache of a bake target from one CI build to the next
#
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
# ========================================================================
#
# Usage (from _build, with REGISTRY and IMAGE set as for bake):
#   tools/bazel_disk_cache.sh seed <target>             before the bake
#   tools/bazel_disk_cache.sh save <target> <bake log>  after the bake
#
# A Bazel build keeps its disk cache in a BuildKit cache mount
# (--mount=type=cache,id=bazel-disk-cache-<target>,...), which never becomes
# part of an image or of the registry build cache. A local builder keeps the
# mount between builds. A GitHub runner starts with an empty builder, so the
# nightly workflow stores the mount as the image
# ${REGISTRY}/${IMAGE}:bazel-disk-cache-<target>:
# - seed copies that image into the cache mount of the job's builder
# - save copies the cache mount into that image, only if the bake ran the
#   Bazel step (a cached step leaves the mount as seeded)
# The contents are spread over four layers to keep each layer small.
#
# Targets without such a cache mount are skipped, so the workflow can call
# this for every target. Errors are not fatal for the build: the workflow runs
# both steps with continue-on-error. DRY_RUN=1 prints the commands.

set -e

ACTION="$1"
TARGET="$2"
BAKE_LOG="$3"

if [ "$ACTION" != "seed" ] && [ "$ACTION" != "save" ] || [ -z "$TARGET" ]; then
	echo "[ERROR] Usage: $0 seed <target> | save <target> <bake log>"
	exit 1
fi
if [ -z "$REGISTRY" ] || [ -z "$IMAGE" ]; then
	echo "[ERROR] REGISTRY and IMAGE must be set."
	exit 1
fi

cd "$(dirname "$0")/.."

# The cache mount option exactly as the Dockerfile has it, so id, target and
# sharing match the build
MOUNT=$(grep -h -o -E -- "--mount=type=cache,id=bazel-disk-cache-${TARGET}(,[^[:space:]\\\\]+)?" images/*/Dockerfile* 2>/dev/null | head -n 1)
if [ -z "$MOUNT" ]; then
	echo "[INFO] $TARGET has no Bazel disk cache mount, nothing to do."
	exit 0
fi
CACHE_DIR=$(echo "$MOUNT" | grep -o -E 'target=[^,]+' | cut -d= -f2)

REF="${REGISTRY}/${IMAGE}:bazel-disk-cache-${TARGET}"
BASE="${BASE:-${REGISTRY}/${IMAGE}:base-dev}"
CTX=$(mktemp -d)
# The cache mount is not part of a step's cache key, so both steps must not be
# taken from the build cache. A new RUN_ID forces them to run. --no-cache would
# do that too, but it also gives the step a new, empty cache mount.
RUN_ID="$(date +%s)-$$"
trap 'rm -rf "$CTX"' EXIT

run() {
	if [ -n "$DRY_RUN" ]; then
		echo "[INFO] Dry run: $*"
		[ -f "$CTX/Dockerfile" ] && sed 's/^/[INFO]   /' "$CTX/Dockerfile"
	else
		"$@"
	fi
}

if [ "$ACTION" = "seed" ]; then
	if [ -z "$DRY_RUN" ] && ! docker buildx imagetools inspect "$REF" > /dev/null 2>&1; then
		echo "[INFO] No Bazel disk cache in $REF yet, $TARGET starts with an empty cache."
		exit 0
	fi
	cat > "$CTX/Dockerfile" <<EOF
FROM ${BASE}
ARG RUN_ID
RUN ${MOUNT} --mount=type=bind,from=seed,target=/seed cp -a /seed/. ${CACHE_DIR}/
EOF
	echo "[INFO] Loading the Bazel disk cache of $TARGET from $REF."
	run docker buildx build --progress=plain --build-arg "RUN_ID=$RUN_ID" \
		--build-context "seed=docker-image://${REF}" \
		--output type=cacheonly "$CTX"
	exit 0
fi

# save
if [ ! -f "$BAKE_LOG" ]; then
	echo "[ERROR] Bake log $BAKE_LOG not found."
	exit 1
fi
# Plain progress prints the step as "#N [stage x/y] RUN ..." and ends it with
# "#N DONE" when it ran or "#N CACHED" when it was reused.
STEP=$(grep -E "^#[0-9]+ \[[^]]*\] RUN .*id=bazel-disk-cache-${TARGET}[,[:space:]]" "$BAKE_LOG" | head -n 1 | cut -d' ' -f1)
if [ -z "$STEP" ] || ! grep -q -E "^${STEP} DONE " "$BAKE_LOG"; then
	echo "[INFO] The Bazel step of $TARGET did not run, the cache is unchanged."
	exit 0
fi

# The split stage copies (not moves) the cache, so a local builder keeps its mount.
cat > "$CTX/Dockerfile" <<EOF
FROM ${BASE} AS split
ARG RUN_ID
RUN ${MOUNT} mkdir -p /out/p0 /out/p1 /out/p2 /out/p3 && cd ${CACHE_DIR} && \\
    find . -mindepth 2 -maxdepth 3 -type d -regex '.*/[0-9a-f][0-9a-f]' | while read -r d; do \\
        case "\${d##*/}" in [0-3]*) p=0 ;; [4-7]*) p=1 ;; [89ab]*) p=2 ;; *) p=3 ;; esac; \\
        mkdir -p "/out/p\$p/\${d%/*}" && cp -a "\$d" "/out/p\$p/\$d"; \\
    done && du -sh /out/p0 /out/p1 /out/p2 /out/p3
FROM scratch
COPY --from=split /out/p0/ /
COPY --from=split /out/p1/ /
COPY --from=split /out/p2/ /
COPY --from=split /out/p3/ /
EOF
echo "[INFO] Saving the Bazel disk cache of $TARGET to $REF."
# zstd compresses the multi-GB layers several times faster than gzip
run docker buildx build --progress=plain --build-arg "RUN_ID=$RUN_ID" --provenance=false --sbom=false \
	--output "type=image,name=${REF},push=true,compression=zstd,compression-level=3,force-compression=true,oci-mediatypes=true" \
	"$CTX"
