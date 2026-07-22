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

# Select the container engine (Docker or Podman), can be overridden by
# setting CONTAINER_ENGINE. Note that with Podman the "--restart always"
# policy does not survive a host reboot unless podman-restart.service (or
# systemd/Quadlet units) are enabled.
if [ -z ${CONTAINER_ENGINE+z} ]; then
    if command -v docker > /dev/null 2>&1; then
        CONTAINER_ENGINE="docker"
    elif command -v podman > /dev/null 2>&1; then
        CONTAINER_ENGINE="podman"
    else
        echo "[ERROR] No container engine found, please install Docker or Podman!"
        exit 1
    fi
fi
export CONTAINER_ENGINE

# general settings for all users
export DOCKER_EXTRA_PARAMS="--cpus 4 --memory 8G --dns 8.8.8.8 --restart always"
export VNC_PORT=0
export EDA_USER_HOME="/var/local/eda"
export EDA_CREDENTIAL_FILE="eda_user_credentials.json"
export EDA_CONTAINER_PREFIX="iic-osic-eda"
export EDA_IMAGE_TAG="latest"
export EDA_USER_GROUP=2000
