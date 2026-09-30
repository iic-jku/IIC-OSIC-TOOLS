#!/bin/bash
# ========================================================================
# Configuration file for eda_server_[start|restart|stop] scripts
#
# SPDX-FileCopyrightText: 2023-2026 Harald Pretl
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

# Select the container engine (Podman or Docker), can be overridden by
# setting CONTAINER_ENGINE. If both work, rootless Podman is preferred. As
# root, Podman would run rootful, so Docker is preferred there instead.
# Containers are only visible to the engine (and, for rootless Podman, to
# the user) that created them, so run all eda_server scripts the same way.
#
# With rootless Podman the containers run as the invoking user, so files in
# the data directories belong to that user on the host, and EDA_USER_GROUP
# only applies inside the containers. The "--restart always" policy needs
# lingering (loginctl enable-linger) to survive a logout, and
# podman-restart.service to survive a host reboot; the start and restart
# scripts check for both. The selection itself is at the end of this file.

# general settings for all users
export DOCKER_EXTRA_PARAMS="--cpus 4 --memory 8G --dns 8.8.8.8 --restart always"
export VNC_PORT=0
export EDA_USER_HOME="/var/local/eda"
export EDA_CREDENTIAL_FILE="eda_user_credentials.json"
export EDA_CONTAINER_PREFIX="iic-osic-eda"
export EDA_IMAGE_TAG="latest"
export EDA_USER_GROUP=2000

# ------------------------------------------------------------------------
# Helper functions shared by the eda_server scripts, nothing to set below.
# ------------------------------------------------------------------------

# Echo "podman" if $1 is Podman, else "docker". Podman can also be called
# as "docker", via the podman-docker wrapper or a symlink (which makes it
# name itself "docker" in --version), but only Podman knows .Host in info.
_engine_kind () {
    if "$1" --version 2>/dev/null | grep -qi "podman" || \
       "$1" info --format '{{.Host.Security.Rootless}}' > /dev/null 2>&1; then
        echo "podman"
    else
        echo "docker"
    fi
}

# Set CONTAINER_ENGINE to the first engine that works, see the top of this
# file. Returns 1 if there is none.
_select_container_engine () {
    local engine engines="podman docker"
    [ "$(id -u)" = 0 ] && engines="docker podman"
    for engine in $engines; do
        command -v "$engine" > /dev/null 2>&1 || continue
        if "$engine" info > /dev/null 2>&1; then
            # Call Podman by its name also when it is found as "docker",
            # so that start_vnc.sh applies its Podman settings.
            if [ "$engine" = docker ] && command -v podman > /dev/null 2>&1 && \
               [ "$(_engine_kind docker)" = podman ]; then
                engine=podman
            fi
            CONTAINER_ENGINE="$engine"
            return 0
        fi
        echo "[WARNING] $engine is installed, but \"$engine info\" failed, so it is not used."
    done
    echo "[ERROR] No working container engine found, please install and start Podman or Docker!"
    return 1
}

# Warn about containers matching the name prefix $1 that the other engine
# holds, e.g. left over from before an engine switch. These are invisible
# to CONTAINER_ENGINE, and their ports collide with new containers.
_hint_other_engine () {
    local prefix="$1"
    local other mine count
    [ -n "$prefix" ] || return 0
    mine=$(${CONTAINER_ENGINE} ps -a -q --no-trunc -f name="$prefix" 2>/dev/null | sort)
    for other in podman docker; do
        [ "$other" = "$CONTAINER_ENGINE" ] && continue
        command -v "$other" > /dev/null 2>&1 || continue
        # Count only containers CONTAINER_ENGINE does not list as well, as
        # "docker" can be Podman, or a Docker CLI on the Podman socket.
        count=$(comm -13 <(echo "$mine") <("$other" ps -a -q --no-trunc -f name="$prefix" 2>/dev/null | sort) | grep -c .)
        if [ "$count" -gt 0 ]; then
            echo "[WARNING] $other holds $count container(s) matching \"$prefix\", which $CONTAINER_ENGINE cannot see."
            echo "[HINT] Manage them with \"CONTAINER_ENGINE=$other $0\"."
        fi
    done
}

# Check the host for what the container engine needs. Rootless Podman runs
# the containers as the invoking user, which needs a few things Docker and
# rootful Podman do not. Returns 1 if no container could start at all.
_check_container_engine () {
    local user info rootless cgroups uidmaps gidmaps controllers
    local param ctrl limits="" missing="" scope=""
    user=$(id -un)

    # Only Podman knows these fields, Docker fails on them
    if ! info=$(${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}} {{.Host.CgroupsVersion}} {{len .Host.IDMappings.UIDMap}} {{len .Host.IDMappings.GIDMap}} {{.Host.CgroupControllers}}' 2>/dev/null); then
        echo "[INFO] Using container engine $CONTAINER_ENGINE."
        return 0
    fi
    read -r rootless cgroups uidmaps gidmaps controllers <<< "$info"
    controllers=" $(echo "$controllers" | tr -d '[]') "

    if [ "$rootless" = true ]; then
        echo "[INFO] Using container engine $CONTAINER_ENGINE (rootless)."
        scope="--user "

        # Without subordinate IDs only the user itself is mapped into the
        # container, which is not enough for the image and EDA_USER_GROUP.
        if [ "$uidmaps" -lt 2 ] || [ "$gidmaps" -lt 2 ]; then
            echo "[ERROR] User $user has no subordinate UID/GID range in /etc/subuid and /etc/subgid, which rootless Podman needs!"
            echo "[HINT] Add one with e.g. \"sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $user\", then run \"podman system migrate\"."
            return 1
        fi

        # Resource limits need the matching cgroup v2 controllers delegated
        # to the user, otherwise every container fails to start.
        for param in $DOCKER_EXTRA_PARAMS; do
            case "$param" in
                --cpuset-*) ctrl=cpuset ;;
                --cpus|--cpus=*|--cpu-*) ctrl=cpu ;;
                -m|--memory|--memory=*|--memory-*) ctrl=memory ;;
                --pids-limit|--pids-limit=*) ctrl=pids ;;
                *) continue ;;
            esac
            limits=1
            case "$controllers$missing " in
                *" $ctrl "*) ;;
                *) missing="$missing $ctrl" ;;
            esac
        done
        if [ -n "$limits" ] && [ "$cgroups" != v2 ]; then
            echo "[WARNING] Rootless Podman ignores the resource limits in DOCKER_EXTRA_PARAMS on this cgroup $cgroups host."
        elif [ -n "$missing" ]; then
            echo "[ERROR] The resource limits in DOCKER_EXTRA_PARAMS need the cgroup controller(s)$missing, which are not delegated to user $user!"
            echo "[HINT] Delegate them with \"[Service]\" and \"Delegate=cpu cpuset io memory pids\" in /etc/systemd/system/user@.service.d/delegate.conf,"
            echo "[HINT] then run \"sudo systemctl daemon-reload\" and log in again, or remove the limits from DOCKER_EXTRA_PARAMS."
            return 1
        fi

        # Without lingering systemd stops all processes of the user, and so
        # the containers, when the last session of the user ends.
        if [[ "$OSTYPE" == "linux"* ]] && command -v loginctl > /dev/null 2>&1 && \
           [ "$(loginctl show-user "$user" --property=Linger --value 2>/dev/null)" = "no" ]; then
            echo "[WARNING] Lingering is off for user $user, so the containers are stopped when $user logs out!"
            echo "[HINT] Switch it on with \"sudo loginctl enable-linger $user\"."
        fi

        if [[ "$OSTYPE" == "linux"* ]] && [ "$EDA_USER_GROUP" != "$(id -g)" ]; then
            echo "[INFO] Files in the data directories belong to user $user on the host, group ID $EDA_USER_GROUP applies inside the containers only."
        fi
    else
        echo "[INFO] Using container engine $CONTAINER_ENGINE (rootful)."
    fi

    # Podman has no daemon that restarts the containers after a host reboot,
    # podman-restart.service does that (for rootless mode it needs lingering).
    if [[ "$OSTYPE" == "linux"* ]] && [[ "$DOCKER_EXTRA_PARAMS" == *"--restart"* ]] && command -v systemctl > /dev/null 2>&1; then
        # shellcheck disable=SC2086
        if [ "$(systemctl $scope is-enabled podman-restart.service 2>/dev/null)" = "disabled" ]; then
            echo "[HINT] The containers are not restarted after a host reboot unless you run \"systemctl ${scope}enable podman-restart.service\"."
        fi
    fi
    return 0
}

# Select the container engine, unless set already
if [ -z "${CONTAINER_ENGINE}" ] && ! _select_container_engine; then
    exit 1
fi
export CONTAINER_ENGINE
