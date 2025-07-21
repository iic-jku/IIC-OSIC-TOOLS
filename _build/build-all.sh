#!/bin/bash
# ========================================================================
# Build script for DIC docker images (build-all)
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

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="iic-osic-tools-builder"
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

if [ -z ${DOCKER_LOAD+z} ]; then
	load_or_push="--push"
else
	load_or_push="--load"
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


#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --push base
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --push tools-level-1
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --push tools-level-2
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --push tools-level-3

# Build the final images, pushing them to the local registry. The Tag in this case is used for the environment variable inside the container.
#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --set *.args.CONTAINER_TAG="${CONTAINER_TAG}" --push images

# Now pull the individual images from the local registry.
${ECHO_IF_DRY_RUN} docker pull registry.iic.jku.at:5000/iic-osic-tools:latest
#${ECHO_IF_DRY_RUN} docker pull registry.iic.jku.at:5000/iic-osic-tools:latest-analog


# finally, run the pushes individually for each flavor.
# Process set tags:
TAG_PARAMS=""
IFS=',' read -ra P_TAGS <<< "$DOCKER_TAGS"
for i in "${P_TAGS[@]}"; do
        echo "[INFO] Processing Tag \"$i\""
        docker tag registry.iic.jku.at:5000/iic-osic-tools:latest ${DOCKER_USER}/${DOCKER_IMAGE}:${i}
        docker push ${DOCKER_USER}/${DOCKER_IMAGE}:${i}
        # For other flavors, handle like this.
        #docker tag registry.iic.jku.at:5000/iic-osic-tools:latest-analog ${DOCKER_USER}/${DOCKER_IMAGE}:${i}-analog                                                                                              
        #docker push ${DOCKER_USER}/${DOCKER_IMAGE}:${i}-analog
done
