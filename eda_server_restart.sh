#!/bin/bash
# ========================================================================
# Restarts multiple IIC-OSIC-TOOLS containers for many EDA users
#
# SPDX-FileCopyrightText: 2023-2025 Harald Pretl
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

set -euo pipefail

# Get configuration variables
if [ ! -f "eda_server_conf.sh" ]; then
    echo "[ERROR] Configuration file eda_server_conf.sh not found!"
    exit 1
fi
# shellcheck source=/dev/null
source eda_server_conf.sh

# Variables for script control
DEBUG=0

# Process input parameters
while getopts "hdf:g:t:" flag; do
    case $flag in
        d)
            echo "[INFO] DEBUG is enabled!"
            DEBUG=1
            ;;
        f)
            [ "$DEBUG" = 1 ] && echo "[INFO] Flag -f is set to $OPTARG."
            EDA_CREDENTIAL_FILE=${OPTARG}
            ;;
        g)
            [ "$DEBUG" = 1 ] && echo "[INFO] Flag -g is set to $OPTARG."
            EDA_USER_GROUP=${OPTARG}
            ;;
        t)
            [ "$DEBUG" = 1 ] && echo "[INFO] Flag -t is set to $OPTARG."
            EDA_IMAGE_TAG=${OPTARG}
            ;;
        h)
         	echo
            echo "Restarting Docker instances for EDA users (ICD@JKU)"
            echo
            echo "Usage: $0 [-h] [-d] [-f credential_file] [-g user_group] [-t image_tag]"
            echo
            echo "       -h shows a help screen"
            echo "       -d enables the debug mode"
            echo "       -f sets the name of the credentials file (default $EDA_CREDENTIAL_FILE)"
            echo "       -g sets the used group-ID (default $EDA_USER_GROUP)"
            echo "       -t sets the Docker image tag to use (default $EDA_IMAGE_TAG)"
            echo
            exit 0
            ;;
        *)
            echo "[ERROR] Invalid option!"
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# Print a bit of status information
[ "$DEBUG" = 1 ] && echo "[INFO] User credentials are read from $EDA_CREDENTIAL_FILE."

# Here is a function for the actual work
_spin_up_server () {
    # $1 = username (e.g. user01)
    # $2 = password
    # $3 = webserver port (in the range of 50000-50200)
    # $4 = container name
    # $5 = data directory

    local username="$1"
    local password="$2" 
    local webport="$3"
    local containername="$4"
    local datadir="$5"

    export DESIGNS="$datadir"
    export VNC_PW="$password"
    export CONTAINER_NAME="$containername"
    export WEBSERVER_PORT="$webport"
    export CONTAINER_GROUP="$EDA_USER_GROUP"
    export DOCKER_TAG="$EDA_IMAGE_TAG"

    [ "$DEBUG" = 1 ] && echo "[INFO] Spinning up container $CONTAINER_NAME using data directory $DESIGNS, webserver port $WEBSERVER_PORT, VNC password $VNC_PW, group-ID $CONTAINER_GROUP, container tag $DOCKER_TAG."

    if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
        echo "[WARNING] Container $CONTAINER_NAME is already running, skipping!"
        return 1
    fi

    if [ ! -d "$DESIGNS" ]; then
        echo "[ERROR] User directory $DESIGNS not found, skipping user $username!"
        return 1
    fi

    # Now spinning up the EDA container using standard scripts
    # shellcheck source=/dev/null
    if ! source start_vnc.sh; then
        echo "[ERROR] Failed to start container for user $username"
        return 1
    fi
    
    echo "[INFO] Successfully started container $CONTAINER_NAME"
}

# Sanitize input parameters
if [ ! -d "$EDA_USER_HOME" ]; then
    echo "[ERROR] User home directory $EDA_USER_HOME not found!"
    exit 1
elif [ ! -w "$EDA_USER_HOME" ]; then
    echo "[ERROR] User home directory $EDA_USER_HOME is not writable!"
    exit 1
fi

# Check a few dependencies
if ! command -v jq >/dev/null 2>&1; then
  echo "[ERROR] The program jq is not installed!"
  exit 1
fi

if [ ! -f "$EDA_CREDENTIAL_FILE" ]; then
    echo "[ERROR] Credential file $EDA_CREDENTIAL_FILE not found!"
    exit 1
fi

# Here is the loop
echo "[INFO] Starting EDA server instances."

if ! NUMBER_USERS=$(jq '. | length' "$EDA_CREDENTIAL_FILE" 2>/dev/null); then
    echo "[ERROR] Failed to parse JSON file $EDA_CREDENTIAL_FILE"
    exit 1
fi

SUCCESSFUL=0
FAILED=0

for i in $(seq 0 $((NUMBER_USERS - 1)))
do
    USERNAME=$(jq -r ".[$i].user // empty" "$EDA_CREDENTIAL_FILE" 2>/dev/null)
    PASSWD=$(jq -r ".[$i].password // empty" "$EDA_CREDENTIAL_FILE" 2>/dev/null)
    PORTNO=$(jq -r ".[$i].port // empty" "$EDA_CREDENTIAL_FILE" 2>/dev/null)
    DOCKERVM=$(jq -r ".[$i].dockervm // empty" "$EDA_CREDENTIAL_FILE" 2>/dev/null)
    DATADIR=$(jq -r ".[$i].datadir // empty" "$EDA_CREDENTIAL_FILE" 2>/dev/null)
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWD" ] || [ -z "$PORTNO" ] || [ -z "$DOCKERVM" ] || [ -z "$DATADIR" ]; then
        echo "[ERROR] Invalid or missing data for user at index $i, skipping!"
        ((FAILED++))
        continue
    fi
    
    [ "$DEBUG" = 1 ] && echo "[INFO] Creating container with user=$USERNAME, using port=$PORTNO, with password=$PASSWD, using container=$DOCKERVM, with datadir=$DATADIR."

    if _spin_up_server "$USERNAME" "$PASSWD" "$PORTNO" "$DOCKERVM" "$DATADIR"; then
        ((SUCCESSFUL++))
    else
        ((FAILED++))
    fi
done

echo
echo "[INFO] Summary: $SUCCESSFUL containers started successfully, $FAILED failed."
if [ "$FAILED" -gt 0 ]; then
    echo "[WARNING] Some containers failed to start. Check the logs above."
    exit 1
fi
echo "[INFO] EDA containers are up and running!"
echo "[DONE] Bye!"
