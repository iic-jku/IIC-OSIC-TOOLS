#!/bin/bash
# ========================================================================
# Build script for ICD@JKU docker images (bake-push)
#
# SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
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
# Usage: bake-push.sh [bake options] <target|group>...
#
# Builds and pushes bake targets with one bake per platform, then merges the
# per-arch images into multi-arch tags. A multi-platform bake on a builder
# with one node per platform exports each registry cache manifest from both
# nodes to the same ref, so only the platform that finishes last keeps its
# cache. Here each platform pushes its images and cache to its own image name
# ${IMAGE}-<arch>, and the merge recreates the usual ${IMAGE}:<tag> tags.
#
# Environment: BUILDER_NAME, PLATFORMS (default linux/amd64,linux/arm64),
# REGISTRY and IMAGE (defaults as in docker-bake.hcl), FINAL_TAGS (comma
# separated full refs for image-full, required when image-full is built),
# BAKE_LOG_DIR (where the full build logs go), BAKE_VERBOSE (any value prints
# the full build output instead of the summary), DRY_RUN.

set -e
set -o pipefail

if [ $# -eq 0 ]; then
	echo "[ERROR] No target specified. Usage: $0 [bake options] <target|group>..."
	exit 1
fi

if [ -n "${DRY_RUN}" ]; then
	ECHO_IF_DRY_RUN="echo $"
fi

BUILDER_NAME="${BUILDER_NAME:-tools-builder-$USER}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
REGISTRY="${REGISTRY:-registry.iic.jku.at:5000}"
IMAGE="${IMAGE:-iic-osic-tools}"
export REGISTRY MERGED_IMAGE="${IMAGE}"

IFS=',' read -ra P_PLATS <<< "$PLATFORMS"
ARCHS=()
for p in "${P_PLATS[@]}"; do
	ARCHS+=("${p#linux/}")
done

# Resolve the targets and their tags with the first arch's image name
BAKE_JSON=$(IMAGE="${IMAGE}-${ARCHS[0]}" PLATFORMS="${P_PLATS[0]}" docker buildx bake --print "$@" 2>/dev/null)
mapfile -t TARGETS < <(python3 -c 'import json,sys; print("\n".join(sorted(json.load(sys.stdin)["target"])))' <<< "$BAKE_JSON")
BUILDS_FULL=0
for t in "${TARGETS[@]}"; do
	[ "$t" = "image-full" ] && BUILDS_FULL=1
done
if [ "$BUILDS_FULL" = 1 ] && [ -z "${FINAL_TAGS}" ]; then
	echo "[ERROR] image-full is built, but FINAL_TAGS is not set."
	exit 1
fi
echo "[INFO] Building ${TARGETS[*]} for ${ARCHS[*]}"

BAKE_LOG_DIR="${BAKE_LOG_DIR:-${TMPDIR:-/tmp}/iic-osic-tools-build/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "${BAKE_LOG_DIR}"
echo "[INFO] Full build logs: ${BAKE_LOG_DIR}/bake-<arch>.log"

# Summary of the plain progress output: a line when a RUN step starts and
# when it ends, nothing for cached steps, plus the errors. A step header
# is buffered until its next line shows whether the step is CACHED. A cache
# ref that does not exist yet (first build of an arch, a GCed cache) is only
# a warning in BuildKit, so it is left out.
summarize() {
	awk -v arch="$1" '
	function out(msg) { printf "[%s %s] %s\n", arch, strftime("%H:%M:%S"), msg; fflush() }
	function short(t) { return length(t) > 110 ? substr(t, 1, 107) "..." : t }
	/failed to configure registry cache importer/ { next }
	/^#[0-9]+ \[/ {
		id = $1; t = substr($0, length(id) + 2)
		if (t ~ /\] RUN / && !(id in hdr)) { hdr[id] = short(t); started[id] = 0 }
		next
	}
	/^#[0-9]+ / {
		id = $1
		if (!(id in hdr)) { if ($2 == "ERROR:") out(substr($0, length(id) + 2)); next }
		if ($2 == "CACHED") { delete hdr[id]; next }
		if ($2 == "...") next
		if ($2 == "DONE") { out("done " $3 "  " hdr[id]); delete hdr[id]; next }
		if ($2 == "ERROR:") { out("FAILED " hdr[id]); out(substr($0, length(id) + 2)); delete hdr[id]; next }
		if (!started[id]) { out("start  " hdr[id]); started[id] = 1 }
		next
	}
	/^ERROR:|^error:/ { out($0) }
	'
}

# One bake per platform, in parallel. Each runs on the builder node of its
# platform. image-full has no default tag, so it gets a per-arch "latest".
PIDS=()
for i in "${!ARCHS[@]}"; do
	a="${ARCHS[i]}"
	FULL_TAG_ARG=()
	if [ "$BUILDS_FULL" = 1 ]; then
		FULL_TAG_ARG=(--set "image-full.tags=${REGISTRY}/${IMAGE}-${a}:latest")
	fi
	(
		export IMAGE="${IMAGE}-${a}" PLATFORMS="${P_PLATS[i]}"
		log="${BAKE_LOG_DIR}/bake-${a}.log"
		if [ -n "${DRY_RUN}" ] || [ -n "${BAKE_VERBOSE}" ]; then
			${ECHO_IF_DRY_RUN} docker buildx bake --builder "${BUILDER_NAME}" --progress=plain --push "${FULL_TAG_ARG[@]}" "$@" 2>&1 | tee "$log" | sed -u "s/^/[${a}] /"
		elif ! docker buildx bake --builder "${BUILDER_NAME}" --progress=plain --push "${FULL_TAG_ARG[@]}" "$@" 2>&1 | tee "$log" | summarize "$a"; then
			echo "[ERROR] The ${a} build failed. Last lines of ${log}:"
			tail -n 40 "$log" | sed "s/^/[${a}] /"
			exit 1
		fi
	) &
	PIDS+=($!)
done
FAILED=0
for pid in "${PIDS[@]}"; do
	wait "$pid" || FAILED=1
done
if [ "$FAILED" = 1 ]; then
	echo "[ERROR] The build failed for at least one platform, not merging the images."
	exit 1
fi

# Merge the per-arch images into multi-arch tags
merge() {
	local dest="$1" tag="$2" srcs=()
	for a in "${ARCHS[@]}"; do
		srcs+=("${REGISTRY}/${IMAGE}-${a}:${tag}")
	done
	echo "[INFO] Merging ${dest}"
	if [ -n "${DRY_RUN}" ]; then
		echo "$ docker buildx imagetools create --builder ${BUILDER_NAME} --tag ${dest} ${srcs[*]}"
	elif ! docker buildx imagetools create --builder "${BUILDER_NAME}" --tag "${dest}" "${srcs[@]}" >> "${BAKE_LOG_DIR}/merge.log" 2>&1; then
		echo "[ERROR] Merging ${dest} failed, see ${BAKE_LOG_DIR}/merge.log"
		exit 1
	fi
}
for t in "${TARGETS[@]}"; do
	if [ "$t" = "image-full" ]; then
		IFS=',' read -ra F_TAGS <<< "$FINAL_TAGS"
		for f in "${F_TAGS[@]}"; do
			merge "$f" latest
		done
		continue
	fi
	mapfile -t TAGS < <(python3 -c 'import json,sys; [print(x.rsplit(":",1)[1]) for x in json.load(sys.stdin)["target"][sys.argv[1]].get("tags",[])]' "$t" <<< "$BAKE_JSON")
	for tag in "${TAGS[@]}"; do
		merge "${REGISTRY}/${IMAGE}:${tag}" "${tag}"
	done
done
echo "[INFO] Done."
