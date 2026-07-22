#!/bin/bash
# ========================================================================
# Start script for ICD@JKU docker images (shell)
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

if [ -n "${DRY_RUN}" ]; then
	echo "[INFO] This is a dry run, all commands will be printed to the shell (Commands printed but not executed are marked with $)!"
	ECHO_IF_DRY_RUN="echo $"
fi

# Select the container engine (Docker or Podman), can be overridden by
# setting CONTAINER_ENGINE.
if [ -z ${CONTAINER_ENGINE+z} ]; then
	if command -v docker > /dev/null 2>&1; then
		CONTAINER_ENGINE="docker"
	elif command -v podman > /dev/null 2>&1; then
		CONTAINER_ENGINE="podman"
	else
		echo "[ERROR] No container engine found, please install Docker or Podman!"
		exit 1
	fi
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Container engine auto-set to ${CONTAINER_ENGINE}."
fi

# Detect Podman rootless mode on Linux (the docker CLI can also be the
# podman-docker alias, so check the version string).
if [[ "$OSTYPE" == "linux"* ]] && ${CONTAINER_ENGINE} --version 2>/dev/null | grep -qi "podman"; then
	if ${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi "true"; then
		ENGINE_IS_ROOTLESS=1
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Podman rootless mode detected."
	fi
fi

# SET YOUR DESIGN PATH RIGHT!
if [ -z ${DESIGNS+z} ]; then
	DESIGNS=$HOME/eda/designs
	if [ ! -d "$DESIGNS" ]; then
		${ECHO_IF_DRY_RUN} mkdir -p "$DESIGNS"
	fi
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Design directory auto-set to $DESIGNS."
fi

if [ -z ${DOCKER_USER+z} ]; then
	DOCKER_USER="hpretl"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
	DOCKER_IMAGE="iic-osic-tools"
fi

if [ -z ${DOCKER_TAG+z} ]; then
	DOCKER_TAG="latest"
fi

# Fully qualify the image name (Podman does not resolve short names
# non-interactively); set DOCKER_REGISTRY="" to use unqualified names.
if [ -z ${DOCKER_REGISTRY+z} ]; then
	DOCKER_REGISTRY="docker.io"
fi
if [ -n "${DOCKER_REGISTRY}" ]; then
	IMAGE_NAME="${DOCKER_REGISTRY}/${DOCKER_USER}/${DOCKER_IMAGE}:${DOCKER_TAG}"
else
	IMAGE_NAME="${DOCKER_USER}/${DOCKER_IMAGE}:${DOCKER_TAG}"
fi

# Shell starts as root per default.
if [ -z ${CONTAINER_USER+z} ]; then
	CONTAINER_USER="0"
fi

if [ -z ${CONTAINER_GROUP+z} ]; then
	CONTAINER_GROUP="0"
fi

if [ -z ${CONTAINER_NAME+z} ]; then
	CONTAINER_NAME="iic-osic-tools_shell_uid_"$(id -u)
fi

if [ -z ${DISP+z} ]; then
	DISP=":0"
fi

# Check for UIDs and GIDs below 1000, except 0 (root)
if [[ ${CONTAINER_USER} -ne 0 ]]  &&  [[ ${CONTAINER_USER} -lt 1000 ]]; then
	prt_str="# [WARNING] Selected User ID ${CONTAINER_USER} is below 1000. This ID might interfere with User-IDs inside the container and cause undefined behavior! #"
	printf -- '#%.0s' $(seq 1 ${#prt_str})
	echo
	echo "${prt_str}"
	printf -- '#%.0s' $(seq 1 ${#prt_str})
	echo
fi

if [[ ${CONTAINER_GROUP} -ne 0 ]]  && [[ ${CONTAINER_GROUP} -lt 1000 ]]; then
	prt_str="# [WARNING] Selected Group ID ${CONTAINER_GROUP} is below 1000. This ID might interfere with Group-IDs inside the container and cause undefined behavior! #"
	printf -- '#%.0s' $(seq 1 ${#prt_str})
	echo
	echo "${prt_str}"
	printf -- '#%.0s' $(seq 1 ${#prt_str})
	echo
fi

# Fixed potential errors in the container due to reduced access to syscalls.
DOCKER_EXTRA_PARAMS="--security-opt seccomp=unconfined ${DOCKER_EXTRA_PARAMS}"

# In Podman rootless mode, keep the host UID/GID inside the container so
# bind-mounted files keep their ownership (see README section 5.1). Not
# needed for the default root shell, where container root maps to the host
# user anyway.
if [ -n "${ENGINE_IS_ROOTLESS}" ] && [ "${CONTAINER_USER}" != "0" ]; then
	if ! echo "${DOCKER_EXTRA_PARAMS}" | grep -q "userns"; then
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Adding --userns=keep-id for Podman rootless mode."
		DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} --userns=keep-id"
	fi
fi

if [ -n "${IIC_OSIC_TOOLS_QUIET}" ]; then
	DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e IIC_OSIC_TOOLS_QUIET=1"
fi

# Check if the container exists and if it is running.
if [ "$(${CONTAINER_ENGINE} ps -q -f name="${CONTAINER_NAME}")" ]; then
	echo "[WARNING] Container is running!"
	echo "[HINT] It can also be stopped with \"${CONTAINER_ENGINE} stop ${CONTAINER_NAME}\" and removed with \"${CONTAINER_ENGINE} rm ${CONTAINER_NAME}\" if required."
	echo
	echo -n "Press \"s\" to stop, and \"r\" to stop & remove: "
	read -r -n 1 k </dev/tty
	echo
	if [[ $k = s ]] ; then
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" stop "${CONTAINER_NAME}"
	elif [[ $k = r ]] ; then
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" stop "${CONTAINER_NAME}"
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" rm "${CONTAINER_NAME}"
	fi
# If the container exists but is exited, it is restarted.
elif [ "$(${CONTAINER_ENGINE} ps -aq -f name="${CONTAINER_NAME}")" ]; then
	echo "[WARNING] Container ${CONTAINER_NAME} exists."
	echo "[HINT] It can also be restarted with \"${CONTAINER_ENGINE} start ${CONTAINER_NAME}\" or removed with \"${CONTAINER_ENGINE} rm ${CONTAINER_NAME}\" if required."
	echo
	echo -n "Press \"s\" to start, and \"r\" to remove: "
	read -r -n 1 k </dev/tty
	echo
	if [[ $k = s ]] ; then
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" start -a -i "${CONTAINER_NAME}"
	elif [[ $k = r ]] ; then
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" rm "${CONTAINER_NAME}"
	fi
else
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Container does not exist, creating ${CONTAINER_NAME} ..."
	# Finally, run the container, and set DISPLAY to the local display number
	#${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" pull "${IMAGE_NAME}"
	# Disable SC2086, $PARAMS must be globbed and splitted.
	# shellcheck disable=SC2086
	${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" run -it --name "${CONTAINER_NAME}" --user "${CONTAINER_USER}:${CONTAINER_GROUP}" -e "DISPLAY=${DISP}" $DOCKER_EXTRA_PARAMS -v "${DESIGNS}":"/foss/designs":rw "${IMAGE_NAME}" -s /bin/bash
fi
