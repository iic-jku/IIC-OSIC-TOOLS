#!/bin/bash
# ========================================================================
# Stops and removes multiple IIC-OSIC-TOOLS containers for many EDA users
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

# get configuration variables
if [ ! -f "eda_server_conf.sh" ]; then
    echo "[ERROR] Configuration file eda_server_conf.sh not found!"
    exit 1
fi
# shellcheck source=/dev/null
source eda_server_conf.sh

# variables for script control
DEBUG=0

# process input parameters
while getopts "hdm:" flag; do
	case $flag in
		d)
			echo "[INFO] DEBUG is enabled"
			DEBUG=1
			;;
		m)
			[ "$DEBUG" = 1 ] && echo "[INFO] Flag -m is set to $OPTARG."
			EDA_CONTAINER_PREFIX=${OPTARG}
			;;	
		h)
			echo
			echo "Stopping Docker instances for EDA users (ICD@JKU)"
			echo
			echo "Usage: $0 [-h] [-d] [-m cont_prefix]"
			echo
			echo "       -h shows a help screen"
			echo "       -d enables the debug mode"
			echo "       -m sets the name prefix of the container (default $EDA_CONTAINER_PREFIX)"
			echo 
			exit
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# Snapshot the matching container IDs once, then iterate. This avoids an
# infinite loop if stop/rm fails for any container (e.g. permission issues).
echo "[INFO] Stopping and removing EDA containers."
NO_INSTANCES=0
FAILED=0
mapfile -t CONTAINER_IDS < <(docker ps -a -q -f name="$EDA_CONTAINER_PREFIX")

if [ "${#CONTAINER_IDS[@]}" -eq 0 ]; then
	echo "[INFO] No matching containers found."
	echo "[DONE] Bye!"
	exit 0
fi

for CONTAINER_ID in "${CONTAINER_IDS[@]}"; do
	[ "$DEBUG" = 1 ] && echo "[INFO] Container ID $CONTAINER_ID found, now stopping and removing!"
	if ! docker stop "$CONTAINER_ID" > /dev/null; then
		echo "[ERROR] Failed to stop container $CONTAINER_ID, skipping."
		FAILED=$((FAILED + 1))
		continue
	fi
	if ! docker rm "$CONTAINER_ID" > /dev/null; then
		echo "[ERROR] Failed to remove container $CONTAINER_ID, skipping."
		FAILED=$((FAILED + 1))
		continue
	fi
	NO_INSTANCES=$((NO_INSTANCES + 1))
	echo "[INFO] Container nr. $NO_INSTANCES stopped and removed."
done

if [ "$FAILED" -gt 0 ]; then
	echo "[WARNING] $FAILED container(s) could not be stopped/removed."
	echo "[DONE] Bye!"
	exit 1
fi

echo "[INFO] All EDA containers have been stopped and removed!"
echo "[DONE] Bye!"
exit 0
