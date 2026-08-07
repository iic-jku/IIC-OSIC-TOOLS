#!/bin/bash
# ========================================================================
# Start script for ICD@JKU docker images (VNC)
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

# Detect Podman, and Podman rootless mode (the docker CLI can also be the
# podman-docker alias, so check the version string). On macOS and Windows the
# Podman machine VM is rootless by default as well, and its rootlessport
# helper has the same restriction on publishing privileged ports.
if ${CONTAINER_ENGINE} --version 2>/dev/null | grep -qi "podman"; then
	ENGINE_IS_PODMAN=1
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

# Set the host ports, and disable them with 0. Only used if not set as shell variables!
if [ -z ${WEBSERVER_PORT+z} ]; then
	if [ -n "${ENGINE_IS_ROOTLESS}" ]; then
		# Rootless Podman cannot bind ports below 1024 by default.
		WEBSERVER_PORT=8080
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Webserver port auto-set to ${WEBSERVER_PORT} (rootless Podman cannot bind ports below 1024)."
	else
		WEBSERVER_PORT=80
	fi
elif [ -n "${ENGINE_IS_ROOTLESS}" ] && [ "$WEBSERVER_PORT" -gt 0 ] && [ "$WEBSERVER_PORT" -lt 1024 ]; then
	echo "[WARNING] Rootless Podman cannot bind port ${WEBSERVER_PORT} (below 1024) by default, the container will likely fail to start. Use e.g. WEBSERVER_PORT=8080."
fi
if [ -z ${VNC_PORT+z} ]; then
	VNC_PORT=5901
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

if [ -z ${CONTAINER_NAME+z} ]; then
	CONTAINER_NAME="iic-osic-tools_xvnc_uid_"$(id -u)
fi

if [[ "$OSTYPE" == "linux"* ]]; then
	if [ -z ${CONTAINER_USER+z} ]; then
	        CONTAINER_USER=$(id -u)
	fi

	if [ -z ${CONTAINER_GROUP+z} ]; then
	        CONTAINER_GROUP=$(id -g)
	fi
else
	if [ -z ${CONTAINER_USER+z} ]; then
			CONTAINER_USER=1000
	fi

	if [ -z ${CONTAINER_GROUP+z} ]; then
			CONTAINER_GROUP=1000
	fi
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

# In Podman rootless mode on Linux, keep the host UID/GID inside the container
# so bind-mounted files keep their ownership (see README section 5.1). On
# macOS/Windows the mount goes through the Podman machine VM, which handles the
# ID mapping itself, so keep-id is not applied there.
if [ -n "${ENGINE_IS_ROOTLESS}" ] && [[ "$OSTYPE" == "linux"* ]] && [ "${CONTAINER_USER}" != "0" ]; then
	if ! echo "${DOCKER_EXTRA_PARAMS}" | grep -q "userns"; then
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Adding --userns=keep-id for Podman rootless mode."
		DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} --userns=keep-id"
	fi
fi

# Processing ports and other parameters
# Fixed potential errors in the container due to reduced access to syscalls.
if [ -n "${IIC_SERVER_DEPLOYMENT}" ]; then
	PARAMS=""
else
	PARAMS="--security-opt seccomp=unconfined"
fi
# Docker sets this namespaced sysctl to 0 in every container by default,
# Podman does not; it is required so noVNC (running as a non-root user) can
# bind port 80 inside the container.
if [ -n "${ENGINE_IS_PODMAN}" ]; then
	PARAMS="${PARAMS} --sysctl net.ipv4.ip_unprivileged_port_start=0"
fi
if [ "$WEBSERVER_PORT" -gt 0 ]; then
	PARAMS="$PARAMS -p $WEBSERVER_PORT:80"
fi
if [ "$VNC_PORT" -gt 0 ]; then
	PARAMS="$PARAMS -p $VNC_PORT:5901"
fi

if [ -n "${VNC_PW}" ]; then
	PARAMS="${PARAMS} -e VNC_PW=${VNC_PW}"
fi

# Allow configuration of X11 keyboard layout (e.g. us, de, at, …)
DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e XKB_KEYBOARD_LAYOUT=${XKB_KEYBOARD_LAYOUT:-us}"

# Allow configuration of X11 keyboard variant (e.g. pc105, nodeadkeys, …)
DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e XKB_KEYBOARD_VARIANT=${XKB_KEYBOARD_VARIANT:-}"

# On Apple Silicon the Linux VM behind the container engine advertises SVE2 in
# HWCAP2 while base SVE is missing from HWCAP, which cannot happen on real
# hardware, and SVE instructions trap. The AWS-LC/OpenSSL CPU probe trusts the
# SVE2 bit and runs one at library load time, so anything using that dispatch
# (cryptography, and hence cocotb simulations) dies with SIGILL. Pinning
# OPENSSL_armcap makes the probe use the given mask instead of detecting the
# capabilities; 0 is the safe choice and only costs ARM crypto acceleration.
# See KNOWN_ISSUES.md. Export OPENSSL_armcap to pin another mask, or export it
# empty to switch this off.
if [[ "$OSTYPE" == "darwin"* ]] && [ "$(uname -m)" = "arm64" ]; then
	ARMCAP="${OPENSSL_armcap-0}"
	if [ -n "${ARMCAP}" ]; then
		DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e OPENSSL_armcap=${ARMCAP}"
	fi
fi

if [ -n "${IIC_OSIC_TOOLS_QUIET}" ]; then
	DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e IIC_OSIC_TOOLS_QUIET=1"
fi

if [ -n "${DOCKER_EXTRA_PARAMS}" ]; then
	PARAMS="${PARAMS} ${DOCKER_EXTRA_PARAMS}"
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
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" start "${CONTAINER_NAME}"
	elif [[ $k = r ]] ; then
		${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" rm "${CONTAINER_NAME}"
	fi
else
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Container does not exist, creating ${CONTAINER_NAME} ..."
	# Finally, run the container, and sets DISPLAY to the local display number
	#${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" pull "${IMAGE_NAME}"
	# Disable SC2086, $PARAMS must be globbed and splitted.
	# shellcheck disable=SC2086
	if ! ${ECHO_IF_DRY_RUN} "${CONTAINER_ENGINE}" run -d --user "${CONTAINER_USER}:${CONTAINER_GROUP}" $PARAMS -v "$DESIGNS":"/foss/designs":rw --name "${CONTAINER_NAME}" "${IMAGE_NAME}" > /dev/null; then
		echo "[ERROR] Could not start the container ${CONTAINER_NAME}!"
		echo "[HINT] A leftover container can be removed with \"${CONTAINER_ENGINE} rm ${CONTAINER_NAME}\"."
		if [ -n "${ENGINE_IS_ROOTLESS}" ] && [ "$WEBSERVER_PORT" -gt 0 ] && [ "$WEBSERVER_PORT" -lt 1024 ]; then
			echo "[HINT] Rootless Podman cannot publish host ports below 1024, retry with e.g. WEBSERVER_PORT=8080."
		fi
		exit 1
	fi
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && [ "$WEBSERVER_PORT" -gt 0 ] && echo "[INFO] To access the VNC session, open a browser and navigate to http://localhost:${WEBSERVER_PORT}/?password=${VNC_PW:-abc123}"
fi
