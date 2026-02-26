#!/bin/bash
# ========================================================================
# Build script for ICD@JKU docker images (build-all)
#
# SPDX-FileCopyrightText: 2022-2025 Harald Pretl and Georg Zachl
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

if [ -z ${DOCKER_PLATFORMS+z} ]; then
	DOCKER_PLATFORMS="linux/amd64,linux/arm64"
fi

if [ -z ${BUILDER_STRS+z} ]; then
	echo "Defining builder strs"
	BUILDER_STRS="host=ssh://$USER@buildx86,host=ssh://$USER@buildaarch"
fi

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="tools-builder-$USER"
fi

if [ -z ${BUILDX_EXTRA_PARAMS+z} ]; then
	BUILDX_EXTRA_PARAMS=""
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
	${ECHO_IF_DRY_RUN} docker buildx create --name ${BUILDER_NAME} --config ./${BUILDKIT_CONF} --platform ${P_PLATS[0]} ${BUILDER_NAME}-${P_PLATS[0]//\//-} ${BUILDX_EXTRA_PARAMS}
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
		${ECHO_IF_DRY_RUN} docker buildx create --name ${BUILDER_NAME} --config ./${BUILDKIT_CONF} --platform ${P_PLATS[i]} --append ${BUILDER_NAME}-${P_PLATS[i]//\//-} ${BUILDX_EXTRA_PARAMS}
	else
		echo "[INFO] Docker context ${BUILDER_NAME}-${P_PLATS[i]//\//-} already part of builder, not appending..."
	fi
done
