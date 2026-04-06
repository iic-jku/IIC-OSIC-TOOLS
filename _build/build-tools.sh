#!/bin/bash
# ========================================================================
# Build script for ICD@JKU docker images (build-tools)
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

if [ -z ${DOCKER_LOAD+z} ]; then
	load_or_push="--push"
else
	load_or_push="--load"
fi

#shellcheck disable=SC2086
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} ${load_or_push} tools-level-1
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} ${load_or_push} tools-level-2
${ECHO_IF_DRY_RUN} docker buildx bake --builder ${BUILDER_NAME} ${load_or_push} tools-level-3
