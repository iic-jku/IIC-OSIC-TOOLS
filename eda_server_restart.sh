#!/bin/bash
# ========================================================================
# Restarts multiple IIC-OSIC-TOOLS containers for many EDA users
#
# SPDX-FileCopyrightText: 2023-2025 Harald Pretl
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

# get configuration variables
# shellcheck source=/dev/null
source eda_server_conf.sh

# variables for script control
DEBUG=0

# process input parameters
while getopts "hdf:g:l:" flag; do
	case $flag in
		d)
			echo "[INFO] DEBUG is enabled!"
			DEBUG=1
			;;
		f)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -f is set to $OPTARG."
			EDA_CREDENTIAL_FILE=${OPTARG}
			;;
		g)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -g is set to $OPTARG."
			EDA_USER_GROUP=${OPTARG}
			;;
		h)
		 	echo
			echo "Restarting Docker instances for EDA users (IICQC@JKU)"
			echo
			echo "Usage: $0 [-h] [-d] [-f credential_file] [-g user_group] [-l data_directory]"
			echo
			echo "       -h shows a help screen"
			echo "       -d enables the debug mode"
			echo "       -f sets the name of the credentials file (default $EDA_CREDENTIAL_FILE)"
			echo "       -g sets the used group-ID (default $EDA_USER_GROUP)"
			echo "       -l sets the directory of the user homes (default $EDA_USER_HOME)"
			echo
			exit
			;;
		l)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -l is set to $OPTARG."
			EDA_USER_HOME=${OPTARG}
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# print a bit of status information
[ $DEBUG = 1 ] && echo "[INFO] User credentials are read from $EDA_CREDENTIAL_FILE."

# here is a function for the actual work
_spin_up_server () {
	# $1 = username (e.g. user01)
	# $2 = password
	# $3 = webserver port (in the range of 50000-50200)
	# $4 = container prefix

	DESIGNS=$(realpath "$EDA_USER_HOME/$1") && export DESIGNS
	export VNC_PW="$2"
	export CONTAINER_NAME="$4-$1"
	export WEBSERVER_PORT="$3"
	export CONTAINER_GROUP="$EDA_USER_GROUP"

	if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
		echo "[ERROR] Running container instances detected, exiting now!"
		exit 1
	fi

	if [ ! -d "$DESIGNS" ]; then
		echo "[ERROR] User directory $DESIGNS not found, exiting now!"
		exit 1
	fi

	# now spinning up the EDA container using standard scripts
	# shellcheck source=/dev/null
	source start_vnc.sh
}

# sanitize input parameters
if [ ! -d "$EDA_USER_HOME" ]; then
	echo "[ERROR] User home directory $EDA_USER_HOME not found!"
	exit 1
elif [ ! -w "$EDA_USER_HOME" ]; then
		echo "[ERROR] User home directory $EDA_USER_HOME is not writable!"
		exit 1
fi

# check a few dependencies
if ! [ -x "$(command -v jq)" ]; then
  echo "[ERROR] The program jq is not installed!"
  exit 1
fi

# here is the loop
echo "[INFO] Starting EDA server instances."

NUMBER_USERS=$(jq '. | length' "$EDA_CREDENTIAL_FILE")
for i in $(seq 0 $((NUMBER_USERS - 1)))
do
	USERNAME=$(jq -r ".[$i].user" "$EDA_CREDENTIAL_FILE")
	PASSWD=$(jq -r ".[$i].password" "$EDA_CREDENTIAL_FILE")
	PORTNO=$(jq -r ".[$i].port" "$EDA_CREDENTIAL_FILE")
	PREFIX=$(jq -r ".[$i].prefix" "$EDA_CREDENTIAL_FILE")
	if [ "$PREFIX" = "null" ]; then
		echo "[INFO] Old JSON format detected, using default container name prefix."
		PREFIX=$EDA_CONTAINER_PREFIX
	fi

	[ $DEBUG = 1 ] && echo "[INFO] Creating container with user=$USERNAME, using port=$PORTNO, with password=$PASSWD, using prefix=$PREFIX."

	_spin_up_server "$USERNAME" "$PASSWD" "$PORTNO" "$PREFIX"
done

echo
echo "[INFO] EDA containers are up and running!"
echo "[DONE] Bye!"
