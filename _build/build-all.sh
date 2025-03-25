#!/bin/bash
# ========================================================================
# Build script for IICQC docker images (build-all)
#
# SPDX-FileCopyrightText: 2022-2023 Harald Pretl and Georg Zachl
# Johannes Kepler University, Institute for Integrated Circuits and
# Quantum Computing
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

if [ -z ${DOCKER_USER+z} ]; then
	DOCKER_USER="hpretl"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
        DOCKER_IMAGE="iic-osic-tools"
fi

if [ -z ${DOCKER_TAGS+z} ]; then
		CONTAINER_TAG="$(date +"%Y.%m")"
        DOCKER_TAGS="latest,$CONTAINER_TAG"
fi

if [ -z ${DOCKER_PLATFORMS+z} ]; then
	DOCKER_PLATFORMS="linux/amd64,linux/arm64"
fi

if [ -z ${DOCKER_LOAD+z} ]; then
	load_or_push="--push"
else
	load_or_push="--load"
fi

if [ -z ${BUILDER_STRS+z} ]; then
	echo "Defining builder strs"
	#BUILDER_STRS="host=ssh://pretl@buildx86,host=unix:///var/run/docker.sock"
	BUILDER_STRS="host=ssh://pretl@buildx86,host=ssh://pretl@buildaarch"
fi

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="iic-osic-tools-builder"
fi


# Process set tags:
TAG_PARAMS=""
IFS=',' read -ra P_TAGS <<< "$DOCKER_TAGS"
for i in "${P_TAGS[@]}"; do
	echo "[INFO] Using Tag \"$i\""
	TAG_PARAMS="${TAG_PARAMS} --tag ${DOCKER_USER}/${DOCKER_IMAGE}:${i}"
done

if [ -z "${TAG_PARAMS}" ]; then
	echo "[WARNING] No tags set!"
fi

# if a builder already exists (either from a previous run or manually created), we directly run the build command.
# if not, we check for the components and create them if required.

P_PLATS=""
B_STRS=""
IFS=',' read -ra P_PLATS <<< "$DOCKER_PLATFORMS"
IFS=',' read -ra B_STRS <<< "$BUILDER_STRS"
for i in "${!P_PLATS[@]}"; do
	if ! docker context inspect ${BUILDER_NAME}-${P_PLATS[i]//\//-} > /dev/null 2>&1 ; then
		echo "[INFO] Creating docker context ${BUILDER_NAME}-${P_PLATS[i]//\//-}"
		${ECHO_IF_DRY_RUN} docker context create ${BUILDER_NAME}-${P_PLATS[i]//\//-} --docker ${B_STRS[i]}
	else
		echo "[INFO] Docker context ${BUILDER_NAME}-${P_PLATS[i]//\//-} exists, not creating..."
	fi
done
i=0
if ! docker buildx inspect ${BUILDER_NAME} > /dev/null 2>&1 ; then
	echo "[INFO] Creating docker buildx builder ${BUILDER_NAME} with context ${BUILDER_NAME}-${P_PLATS[0]//\//-}"
	BUILDKIT_CONF="buildkitd-${P_PLATS[0]//\//-}.toml"
	if [ ! -f "$BUILDKIT_CONF" ]; then
		echo "[INFO] ${BUILDKIT_CONF} does not exist, using default buildkitd.toml..."
		BUILDKIT_CONF="buildkitd.toml"
	fi
	${ECHO_IF_DRY_RUN} docker buildx create --name ${BUILDER_NAME} --config ./${BUILDKIT_CONF} --platform ${P_PLATS[0]} ${BUILDER_NAME}-${P_PLATS[0]//\//-}
	i=1
else
	echo "[INFO] Docker buildx builder ${BUILDER_NAME} exists, not creating..."
	i=0
fi
for ((;i<"${#P_PLATS[@]}";i++)); do
	if ! docker buildx inspect ${BUILDER_NAME} |grep ${BUILDER_NAME}-${P_PLATS[i]//\//-}  > /dev/null 2>&1 ; then
		BUILDKIT_CONF="buildkitd-${P_PLATS[i]//\//-}.toml"
		if [ ! -f "$BUILDKIT_CONF" ]; then
			echo "[INFO] ${BUILDKIT_CONF} does not exist, using default buildkitd.toml..."
    		BUILDKIT_CONF="buildkitd.toml"
		fi
		echo "[INFO] Appending context ${BUILDER_NAME}-${P_PLATS[i]//\//-} to buildx builder"
		${ECHO_IF_DRY_RUN} docker buildx create --name ${BUILDER_NAME} --config ./${BUILDKIT_CONF} --platform ${P_PLATS[i]} --append ${BUILDER_NAME}-${P_PLATS[i]//\//-}
	else
		echo "[INFO] Docker context ${BUILDER_NAME}-${P_PLATS[i]//\//-} already part of builder, not appending..."
	fi
done

#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx build --platform ${DOCKER_PLATFORMS} --builder ${BUILDER_NAME} ${load_or_push} ${TAG_PARAMS} --build-arg CONTAINER_TAG=${CONTAINER_TAG} .
