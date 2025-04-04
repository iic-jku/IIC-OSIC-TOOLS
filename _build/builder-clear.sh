#!/bin/bash
# ========================================================================
# Build script for IICQC docker images (clear)
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

if [ -z ${BUILDER_NAME+z} ]; then
	BUILDER_NAME="iic-osic-tools-builder"
fi

if [ -z ${DOCKER_PLATFORMS+z} ]; then
        DOCKER_PLATFORMS="linux/amd64,linux/arm64"
fi

# delete the builders in the reversed creation order
if docker buildx inspect "${BUILDER_NAME}" > /dev/null 2>&1 ; then
	echo "[INFO] Deleting docker buildx builder ${BUILDER_NAME}"
	${ECHO_IF_DRY_RUN} docker buildx rm "${BUILDER_NAME}"
fi
P_PLATS=""
IFS=',' read -ra P_PLATS <<< "$DOCKER_PLATFORMS"
for i in "${!P_PLATS[@]}"; do
	if docker context inspect "${BUILDER_NAME}-${P_PLATS[i]//\//-}" > /dev/null 2>&1 ; then
		echo "[INFO] Deleting docker context ${BUILDER_NAME}-${P_PLATS[i]//\//-}"
		${ECHO_IF_DRY_RUN} docker context rm "${BUILDER_NAME}-${P_PLATS[i]//\//-}"
	fi
done
