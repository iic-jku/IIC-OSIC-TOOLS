#!/bin/bash
# ========================================================================
# Start script for DIC docker images (X11)
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

trap cleanup EXIT
cleanup() {
    if [ -n "${SOCAT_PID}" ]; then
        echo "Stopping socat..."
        kill "${SOCAT_PID}" 2>/dev/null || true
        wait "${SOCAT_PID}" 2>/dev/null || true
        echo "socat stopped."
    fi
}


if [ -n "${DRY_RUN}" ]; then
	echo "[INFO] This is a dry run, all commands will be printed to the shell (Commands printed but not executed are marked with $)!"
	ECHO_IF_DRY_RUN="echo $"
fi

if [ -z ${CONTAINER_NAME+z} ]; then
	CONTAINER_NAME="iic-osic-tools_xserver_uid_"$(id -u)
fi

if [ -z ${JUPYTER_PORT+z} ]; then
	JUPYTER_PORT=8888
fi

# Check if the container exists and if it is running.
if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
	echo "[WARNING] Container is running!"
	echo "[HINT] It can also be stopped with \"docker stop ${CONTAINER_NAME}\" and removed with \"docker rm ${CONTAINER_NAME}\" if required."
	echo
	echo -n "Press \"s\" to stop, and \"r\" to stop & remove: "
	read -r -n 1 k <&1
	echo
	if [[ $k = s ]] ; then
		${ECHO_IF_DRY_RUN} docker stop "${CONTAINER_NAME}"
	elif [[ $k = r ]] ; then
		${ECHO_IF_DRY_RUN} docker stop "${CONTAINER_NAME}"
		${ECHO_IF_DRY_RUN} docker rm "${CONTAINER_NAME}"
	fi
fi

PARAMS=""

# SET YOUR DESIGN PATH RIGHT!
if [ -z ${DESIGNS+z} ]; then
	DESIGNS=$HOME/eda/designs
	if [ ! -d "$DESIGNS" ]; then
		${ECHO_IF_DRY_RUN} mkdir -p "$DESIGNS"
	fi
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Design directory auto-set to $DESIGNS."
fi

PARAMS="$PARAMS -v ${DESIGNS}:/foss/designs:rw"

if [ -z ${DOCKER_USER+z} ]; then
	DOCKER_USER="hpretl"
fi

if [ -z ${DOCKER_IMAGE+z} ]; then
	DOCKER_IMAGE="iic-osic-tools"
fi

if [ -z ${DOCKER_TAG+z} ]; then
	DOCKER_TAG="latest"
fi

if [[ "$OSTYPE" == "linux"* ]]; then
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Auto detected Linux."
	# Should also be a sensible default
	if [ -z ${CONTAINER_USER+z} ]; then
	        CONTAINER_USER=$(id -u)
	fi

	if [ -z ${CONTAINER_GROUP+z} ]; then
	        CONTAINER_GROUP=$(id -g)
	fi

	# On Linux, we force the container-side XDG_RUNTIME_DIR to /tmp/runtime-default, if not overwritten
	# Note, this would be the default, also set in env.sh, if not set. As it is required for mounting, it is still defined here
	if [ -z ${CONTAINER_XDG_RUNTIME_DIR+z} ]; then
		CONTAINER_XDG_RUNTIME_DIR="/tmp/runtime-default"
	fi
	PARAMS="${PARAMS} -e XDG_RUNTIME_DIR=${CONTAINER_XDG_RUNTIME_DIR}"

	# Check if Docker is running on Docker Desktop or classic engine
	docker_info=$(docker version --format '{{.Server.Version}} {{.Server.Os}} {{.Server.Platform.Name}}' 2>/dev/null)

	if echo "$docker_info" | grep -iq "Docker Desktop"; then
		# We are running on Docker Desktop, means no forwarded special files...
		if [ -z ${DISP+z} ]; then
			DISP="host.docker.internal:0"
			if [[ $(type -P "xhost") ]]; then
				${ECHO_IF_DRY_RUN} xhost +localhost > /dev/null
			else
				echo "[WARNING] xhost could not be found, access control to the X server might needs to be managed manually!"
			fi
			# If we are running in Wayland, we are using Xwayland. For that we assume that no TCP interface is available.
			# Therefore we have to socat the socket. For X11, this should not be needed.
			echo "Starting socat to enable TCP connections to the X-Server from the container."
			#DISPLAY_NUM=$(echo $DISPLAY | sed 's/^[^:]*:\([0-9]*\).*/\1/')
			DISPLAY_NUM=${DISPLAY#*:}
			DISPLAY_NUM=${DISPLAY_NUM%%.*}
			socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CONNECT:/tmp/.X11-unix/X$DISPLAY_NUM &
			SOCAT_PID=$!
			echo "Started socat with PID ${SOCAT_PID} in the background.."
		fi
		# Always for indirect rendering on MacOS with XQuartz
		FORCE_LIBGL_INDIRECT=1	
	else
		#We run the Docker-CE runtime, which can access special files.
		if [ -z ${XSOCK+z} ]; then
			if [ -d "/tmp/.X11-unix" ]; then
				XSOCK="/tmp/.X11-unix"
			else
				echo "[ERROR] X11 socket could not be found. Please set it manually!"
				exit 1
			fi
		fi
		if [ -z ${DISP+z} ]; then
			if [ -z ${DISPLAY+z} ]; then
				echo "[ERROR] No DISPLAY set!"
				exit 1
			else
				DISP=$DISPLAY
			fi
		fi

		PARAMS="$PARAMS -v $XSOCK:/tmp/.X11-unix:rw"

		# For testing for the Wayland-Display, we simply assume that XDG_RUNTIME_DIR is set correctly.
		if [ -z ${WAYLAND_DISP+z} ]; then
			WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
			WAYLAND_DISP="$WAYLAND_DISPLAY"
			[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Assuming Wayland Socket ${WAYLAND_SOCK}."
		else
			WAYLAND_SOCK="$XDG_RUNTIME_DIR/$WAYLAND_DISP"
		fi

		if [ -S "$WAYLAND_SOCK" ]; then
			[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Wayland Socket exists, forwarding..."
			PARAMS="${PARAMS} -v ${WAYLAND_SOCK}:${CONTAINER_XDG_RUNTIME_DIR}/${WAYLAND_DISP}:rw -e WAYLAND_DISPLAY=${WAYLAND_DISP}"
		else
			[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[WARNING] Wayland socket could not be found. Falling back to X11."
		fi

		if [ -z ${XAUTH+z} ]; then
			# Senseful defaults (uses XAUTHORITY Shell variable if set, or the default .Xauthority -file in the caller home directory)
			if [ -z ${XAUTHORITY+z} ]; then
				if [ -f "$HOME/.Xauthority" ]; then
					XAUTH="$HOME/.Xauthority"
				else
					echo "[ERROR] Xauthority could not be found. Please set it manually!"
					exit 1
				fi
			else
				XAUTH=$XAUTHORITY
			fi
			# Thanks to https://stackoverflow.com/a/25280523
			XAUTH_TMP="/tmp/.${CONTAINER_NAME}_xauthority"
			#create an empty file
			${ECHO_IF_DRY_RUN} echo -n > "${XAUTH_TMP}"
			if [ -z "${ECHO_IF_DRY_RUN}" ]; then
				xauth -f "${XAUTH}" nlist "${DISP}" | sed -e 's/^..../ffff/' | xauth -f "${XAUTH_TMP}" nmerge -
			else
				${ECHO_IF_DRY_RUN} "xauth -f ${XAUTH} nlist ${DISP} | sed -e 's/^..../ffff/' | xauth -f ${XAUTH_TMP} nmerge -"
			fi
			XAUTH=${XAUTH_TMP}
		fi
		PARAMS="$PARAMS -v $XAUTH:/headless/.xauthority:rw -e XAUTHORITY=/headless/.xauthority"
		if [ -d "/dev/dri" ]; then
			[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] /dev/dri detected, forwarding GPU for graphics acceleration."
			PARAMS="${PARAMS} --device=/dev/dri:/dev/dri"
		else
			[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] No /dev/dri detected!"
			FORCE_LIBGL_INDIRECT=1
		fi

		fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
	if [ -z ${CONTAINER_USER+z} ]; then
	        CONTAINER_USER=1000
	fi

	if [ -z ${CONTAINER_GROUP+z} ]; then
	        CONTAINER_GROUP=1000
	fi
	if [ -z ${DISP+z} ]; then
		DISP="host.docker.internal:0"
		if [[ $(type -P "xhost") ]]; then
			${ECHO_IF_DRY_RUN} xhost +localhost > /dev/null
		else
			echo "[WARNING] xhost could not be found, access control to the X server must be managed manually!"
		fi
	fi
	if [ "$(defaults read org.xquartz.x11 enable_iglx)" = 0 ]; then
		${ECHO_IF_DRY_RUN} defaults write org.xquartz.x11 enable_iglx 1
		echo "[INFO] Enabled XQuartz OpenGL for indirect rendering."
		echo "[ERROR] Please restart XQuartz!"
		exit 1
	fi
	# Always for indirect rendering on MacOS with XQuartz
	FORCE_LIBGL_INDIRECT=1
else
	echo "[ERROR] Not setup for ${OSTYPE}!"
	exit 1
fi

if [ -n "${FORCE_LIBGL_INDIRECT}" ]; then
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Using indirect rendering."
	PARAMS="${PARAMS} -e LIBGL_ALWAYS_INDIRECT=1"
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

if [ "${JUPYTER_PORT}" -gt 0 ]; then
	PARAMS="$PARAMS -p $JUPYTER_PORT:8888"
fi

if [ -n "${DOCKER_EXTRA_PARAMS}" ]; then
	PARAMS="${PARAMS} ${DOCKER_EXTRA_PARAMS}"
fi

if [ -n "${IIC_OSIC_TOOLS_QUIET}" ]; then
	DOCKER_EXTRA_PARAMS="${DOCKER_EXTRA_PARAMS} -e IIC_OSIC_TOOLS_QUIET=1"
fi

# If the container exists but is exited, it can be restarted.
if [ "$(docker ps -aq -f name="${CONTAINER_NAME}")" ]; then
	echo "[WARNING] Container ${CONTAINER_NAME} exists."
	echo "[HINT] It can also be restarted with \"docker start ${CONTAINER_NAME}\" or removed with \"docker rm ${CONTAINER_NAME}\" if required."
	echo	
	echo -n "Press \"s\" to start, and \"r\" to remove: "
	read -r -n 1 k <&1
	echo
	if [[ $k = s ]] ; then
		${ECHO_IF_DRY_RUN} docker start "${CONTAINER_NAME}"
	elif [[ $k = r ]] ; then
		${ECHO_IF_DRY_RUN} docker rm "${CONTAINER_NAME}"
	fi
else
	[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Container does not exist, creating ${CONTAINER_NAME}. Please be patient, this can take a few minutes ..."
	# Finally, run the container, and set DISPLAY to the local display number
	${ECHO_IF_DRY_RUN} docker pull "${DOCKER_USER}/${DOCKER_IMAGE}:${DOCKER_TAG}" > /dev/null
	# Disable SC2086, $PARAMS must be globbed and splitted.
	# shellcheck disable=SC2086
	${ECHO_IF_DRY_RUN} docker run -d --user "${CONTAINER_USER}:${CONTAINER_GROUP}" -e "DISPLAY=${DISP}" ${PARAMS} --name "${CONTAINER_NAME}" "${DOCKER_USER}/${DOCKER_IMAGE}:${DOCKER_TAG}" > /dev/null
fi

if [ -n "${SOCAT_PID}" ]; then
	echo "socat is still running. Press Ctrl+C to stop it."
	echo "WARNING: This will kill a running container!"

    # Check if socat is still running and monitor the container status
    while ps -p "${SOCAT_PID}" > /dev/null; do
        # Check if the container is still running
        if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Docker container ${CONTAINER_NAME} is no longer running."
            cleanup
        fi

        # Wait for 1 second before checking again
        sleep 1
    done

	echo "socat or the container is no longer running. Exiting..."
fi
