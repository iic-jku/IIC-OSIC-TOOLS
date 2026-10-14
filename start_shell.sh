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

# --- BEGIN common startup helpers (keep identical in all start_*.sh) ---
# Settings persisted by install.sh. It uses ": ${VAR:=value}", so the environment wins.
IIC_OSIC_TOOLS_CONF="${IIC_OSIC_TOOLS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/iic-osic-tools/env}"
if [ -r "${IIC_OSIC_TOOLS_CONF}" ]; then
	# shellcheck source=/dev/null
	. "${IIC_OSIC_TOOLS_CONF}"
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Loaded settings from ${IIC_OSIC_TOOLS_CONF}."
fi

# SELinux enabled in the host kernel? False on non-SELinux Linux, WSL and macOS.
host_selinux_enabled() {
	if command -v selinuxenabled > /dev/null 2>&1; then
		selinuxenabled
	else
		[ -f /sys/fs/selinux/enforce ]
	fi
}

# Watch a detached container for $1 seconds (default 5) and dump its log if it
# dies, which would otherwise pass unnoticed. Returns 1 if it stopped.
check_container_alive() {
	local timeout=${1:-5}
	local i
	if [ -n "${ECHO_IF_DRY_RUN}" ] || [ -n "${IIC_OSIC_TOOLS_NO_STARTUP_CHECK}" ]; then
		return 0
	fi
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Verifying that the container stays up (up to ${timeout}s) ..."
	for ((i=1; i<=timeout; i++)); do
		sleep 1
		if [ "$(${CONTAINER_ENGINE} inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)" != "true" ]; then
			echo "[ERROR] Container ${CONTAINER_NAME} stopped ${i}s after it was started."
			echo "[ERROR] Last lines of \"${CONTAINER_ENGINE} logs ${CONTAINER_NAME}\":"
			${CONTAINER_ENGINE} logs --tail 20 "${CONTAINER_NAME}" 2>&1 | sed -e 's/^/    /'
			return 1
		fi
	done
	return 0
}

# Errors logged during startup while the container itself stays up.
check_container_log_errors() {
	local errs
	if [ -n "${ECHO_IF_DRY_RUN}" ] || [ -n "${IIC_OSIC_TOOLS_NO_STARTUP_CHECK}" ]; then
		return 0
	fi
	errs=$(${CONTAINER_ENGINE} logs "${CONTAINER_NAME}" 2>&1 | grep -F "[ERROR]" | head -n 5)
	if [ -n "${errs}" ]; then
		echo "[WARNING] The container is running, but reported errors during startup:"
		echo "    ${errs//$'\n'/$'\n'    }"
		echo "[HINT] If the terminal window opened anyway, these can usually be ignored."
		selinux_failure_hint
	fi
}

# Hints for a failed startup on an SELinux host.
selinux_failure_hint() {
	[[ "$OSTYPE" == "linux"* ]] || return 0
	host_selinux_enabled || return 0
	if [ -n "${SELINUX_LABEL}" ]; then
		echo "[HINT] SELinux is enabled, and the container was created with \"--security-opt label=${SELINUX_LABEL}\"."
		echo "[HINT] Check for remaining denials with \"sudo ausearch -m avc -ts recent\", see README section 5.1.1."
	else
		echo "[HINT] SELinux is enabled, but the workaround is switched off via IIC_OSIC_TOOLS_SELINUX_LABEL."
		echo "[HINT] Without it the container cannot access the host X11/Wayland sockets and ${DESIGNS}, see README section 5.1.1."
	fi
}
# --- END common startup helpers ---

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

# Detect Podman, and Podman rootless mode on Linux (the docker CLI can also
# be the podman-docker alias, so check the version string).
if ${CONTAINER_ENGINE} --version 2>/dev/null | grep -qi "podman"; then
	ENGINE_IS_PODMAN=1
	if [[ "$OSTYPE" == "linux"* ]] && ${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi "true"; then
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
# non-interactively); set DOCKER_REGISTRY="" or "none" to use unqualified names.
if [ -z ${DOCKER_REGISTRY+z} ]; then
	DOCKER_REGISTRY="docker.io"
fi
IMAGE_PREFIX="${DOCKER_REGISTRY}/"
if [ -z "${DOCKER_REGISTRY}" ] || [ "${DOCKER_REGISTRY}" = "none" ]; then
	IMAGE_PREFIX=""
fi
# A DOCKER_USER that contains "." or ":", or is "localhost", already names a
# registry (e.g. "myregistry:5000"), so the image name must not be prefixed.
case "${DOCKER_USER}" in
	*.* | *:* | localhost) IMAGE_PREFIX="" ;;
esac
# An empty DOCKER_USER means the image sits at the root of the registry.
IMAGE_PATH="${DOCKER_IMAGE}"
if [ -n "${DOCKER_USER}" ]; then
	IMAGE_PATH="${DOCKER_USER}/${DOCKER_IMAGE}"
fi
IMAGE_NAME="${IMAGE_PREFIX}${IMAGE_PATH}:${DOCKER_TAG}"

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

# Default DISPLAY for GUI tools started from the shell. The X11 socket is not
# mounted in shell mode, so a plain ":0" can never work on macOS; there the
# X server (XQuartz) is reached over TCP via the host gateway, as in
# start_x.sh. On Linux, fall back to the host's DISPLAY (GUI output
# additionally requires forwarding the X socket, e.g. via
# DOCKER_EXTRA_PARAMS="-v /tmp/.X11-unix:/tmp/.X11-unix").
if [ -z ${DISP+z} ]; then
	if [[ "$OSTYPE" == "darwin"* ]]; then
		if [ -n "${ENGINE_IS_PODMAN}" ]; then
			DISP="host.containers.internal:0"
		else
			DISP="host.docker.internal:0"
		fi
	else
		DISP="${DISPLAY:-:0}"
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

# --- BEGIN common SELinux workaround (keep identical in all start_*.sh) ---
# On SELinux hosts the container runs as "container_t", while the bind-mounted
# X11/Wayland sockets keep "user_tmp_t" and the designs directory "user_home_t",
# so access to both is denied (issue #352). The GUI sockets belong to the host
# session and must not be relabeled, so type enforcement is switched off for
# this container; seccomp, capabilities and the user namespace are unaffected.
# See README section 5.1.1. Set IIC_OSIC_TOOLS_SELINUX_LABEL to another label
# option (e.g. "type:container_runtime_t"), or export it empty to switch off.
if [ -n "${IIC_OSIC_TOOLS_SELINUX_LABEL+z}" ]; then
	SELINUX_LABEL="${IIC_OSIC_TOOLS_SELINUX_LABEL}"
elif [[ "$OSTYPE" == "linux"* ]] && host_selinux_enabled; then
	SELINUX_LABEL="disable"
else
	SELINUX_LABEL=""
fi
if [ -n "${SELINUX_LABEL}" ]; then
	if echo "${DOCKER_EXTRA_PARAMS}" | grep -qE -- "--security-opt[= ]label="; then
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] An SELinux label option is already set in DOCKER_EXTRA_PARAMS, not adding another one."
	else
		[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] SELinux detected ($(getenforce 2>/dev/null || echo enabled)), adding \"--security-opt label=${SELINUX_LABEL}\" (see README section 5.1.1)."
		DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} --security-opt label=${SELINUX_LABEL}"
	fi
fi
# --- END common SELinux workaround ---

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
	# --- BEGIN common create-time option check (keep identical in all start_*.sh) ---
	# Container options are fixed at create time, so "start" cannot pick up a new flag.
	CREATED_OPTS=$(${CONTAINER_ENGINE} inspect -f '{{range .HostConfig.SecurityOpt}}{{.}} {{end}}' "${CONTAINER_NAME}" 2>/dev/null)
	if [ -n "${SELINUX_LABEL}" ] && [ -n "${CREATED_OPTS}" ] && ! echo "${CREATED_OPTS}" | grep -q "label="; then
		echo "[WARNING] The existing container was created without \"--security-opt label=${SELINUX_LABEL}\" and will not work on this SELinux host."
		echo "[HINT] Press \"r\" to remove it, then run this script again to re-create it."
	fi
	CREATED_ENV=$(${CONTAINER_ENGINE} inspect -f '{{range .Config.Env}}{{.}} {{end}}' "${CONTAINER_NAME}" 2>/dev/null)
	if [ -n "${ARMCAP}" ] && [ -n "${CREATED_ENV}" ] && ! echo "${CREATED_ENV}" | grep -q "OPENSSL_armcap="; then
		echo "[WARNING] The existing container was created without \"OPENSSL_armcap=${ARMCAP}\" and will crash with SIGILL on this Apple Silicon host (see KNOWN_ISSUES.md)."
		echo "[HINT] Press \"r\" to remove it, then run this script again to re-create it."
	fi
	# --- END common create-time option check ---
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
