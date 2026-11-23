#!/bin/bash
# ========================================================================
# Build script for ICD@JKU docker images (build-target)
#
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
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

set -e

if [ -z "$1" ]; then
	echo "[ERROR] No target specified. Usage: $0 <target>"
	echo "[INFO]  Available targets are defined in docker-bake.hcl"
	exit 1
fi

BUILD_TARGET="$1"

if [ -n "${DRY_RUN}" ]; then
	echo "[INFO] This is a dry run, all commands will be printed to the shell (Commands printed but not executed are marked with $)!"
	ECHO_IF_DRY_RUN="echo $"
fi

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="tools-builder-$USER"
fi

# The IHP PDKs come from branch dev without a pin. Pass the head of dev to bake,
# so open_pdks rebuilds its IHP layers when dev moves instead of using the cache.
if [ -z "${IHP_PDK_COMMIT}" ]; then
	IHP_PDK_COMMIT=$(git ls-remote https://github.com/iic-jku/IHP-Open-PDK.git refs/heads/dev | cut -f1) || true
	echo "[INFO] Head of the IHP PDK branch dev: ${IHP_PDK_COMMIT:-unknown, the IHP layers may come from the cache}"
fi
export IHP_PDK_COMMIT

if [ -z ${DOCKER_LOAD+z} ]; then
	load_or_push="--push"
else
	load_or_push="--load"
fi

if [ -n "${NO_CACHE}" ]; then
	no_cache="--no-cache"
fi

#shellcheck disable=SC2086
# --push goes through bake-push.sh, which keeps a registry cache per arch
if [ "${load_or_push}" = "--load" ]; then
	${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --load ${no_cache} ${BUILD_TARGET}
else
	SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
	BUILDER_NAME="${BUILDER_NAME}" "${SCRIPT_DIR}/bake-push.sh" ${no_cache} ${BUILD_TARGET}
fi
