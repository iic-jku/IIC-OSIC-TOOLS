#!/bin/bash
# ========================================================================
# Build script for ICD@JKU docker images (build-devcontainer)
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

if [ -n "${DRY_RUN}" ]; then
	echo "[INFO] This is a dry run, all commands will be printed to the shell (Commands printed but not executed are marked with $)!"
	ECHO_IF_DRY_RUN="echo $"
fi

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="tools-builder-$USER"
fi

if [ -z ${DOCKER_USER+z} ]; then
	DOCKER_USER="hpretl"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
	DOCKER_IMAGE="iic-osic-tools-devcontainer"
fi

if [ -z ${CONTAINER_TAG+z} ]; then
	CONTAINER_TAG="$(date +"%Y.%m")"
fi

if [ -z ${DOCKER_TAGS+z} ]; then
	DOCKER_TAGS="latest,$CONTAINER_TAG"
fi

if [ -z ${BASE_VERSION+z} ]; then
	BASE_VERSION="$CONTAINER_TAG"
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOCKERFILE="${SCRIPT_DIR}/devcontainer/image/Dockerfile"

# Build tag arguments
TAG_ARGS=""
IFS=',' read -ra P_TAGS <<< "$DOCKER_TAGS"
for i in "${P_TAGS[@]}"; do
	TAG_ARGS="${TAG_ARGS} --tag ${DOCKER_USER}/${DOCKER_IMAGE}:${i}"
done

echo "[INFO] Building devcontainer image based on hpretl/iic-osic-tools:${BASE_VERSION}"
echo "[INFO] Pushing as ${DOCKER_USER}/${DOCKER_IMAGE} with tags: ${DOCKER_TAGS}"

#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx build \
	--builder "${BUILDER_NAME}" \
	--platform linux/amd64,linux/arm64 \
	--build-arg VERSION="${BASE_VERSION}" \
	${TAG_ARGS} \
	--push \
	-f "${DOCKERFILE}" \
	"${SCRIPT_DIR}/devcontainer/image"
