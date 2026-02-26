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

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="tools-builder-$USER"
fi

if [ -z ${DOCKER_PREFIXES+z} ]; then
	DOCKER_PREFIXES="registry.iic.jku.at:5000"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
        DOCKER_IMAGE="iic-osic-tools"
fi

if [ -z ${CONTAINER_TAG+z} ]; then
	CONTAINER_TAG="$(date +"%Y.%m")"
fi

if [ -z ${DOCKER_TAGS+z} ]; then
        DOCKER_TAGS="latest,$CONTAINER_TAG"
fi

# Process set tags:
IFS=',' read -ra P_TAGS <<< "$DOCKER_TAGS"
# Process set prefixes:
IFS=',' read -ra P_PREFIXES <<< "$DOCKER_PREFIXES"

SET_TAGS_CMD=""
for i in "${P_TAGS[@]}"; do
    for j in "${P_PREFIXES[@]}"; do
        echo "[INFO] Processing Tag \"$i\" with Prefix \"$j\""
		#SET_TAGS_CMD="${SET_TAGS_CMD} --set image-full.tags+='${j}/${DOCKER_IMAGE}:${i}' --set image-analog.tags+='${j}/${DOCKER_IMAGE}:${i}-analog' --set image-digital.tags+='${j}/${DOCKER_IMAGE}:${i}-digital' --set image-riscv.tags+='${j}/${DOCKER_IMAGE}:${i}-riscv'"
		SET_TAGS_CMD="${SET_TAGS_CMD} --set image-full.tags=${j}/${DOCKER_IMAGE}:${i}"
    done
done

# First, build the images, pushing them to the local registry. The Tag in this case is used for the environment variable inside the container.
#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} --set *.args.CONTAINER_TAG="${CONTAINER_TAG}" ${SET_TAGS_CMD} --push images
