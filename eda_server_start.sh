#!/bin/bash
# ========================================================================
# Spins up multiple IIC-OSIC-TOOLS containers for many EDA users
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

# get configuration variables
# shellcheck source=/dev/null
source eda_server_conf.sh

# variables for script control
DEBUG=0
DO_CLEAN=0
DO_KILL=0
START_PORT=50001
NUMBER_USERS=20
PASSWD_DIGITS=20

# process input parameters
while getopts "hcdkp:n:s:f:g:l:m:" flag; do
	case $flag in
		c)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -c is set."
			DO_CLEAN=1
			;;
		p)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -p is set to $OPTARG."
			START_PORT=${OPTARG}
			;;
		d)
			echo "[INFO] DEBUG is enabled!"
			DEBUG=1
			;;
		n)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -n is set to $OPTARG."
			NUMBER_USERS=${OPTARG}
			;;
		s)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -s is set to $OPTARG."
			PASSWD_DIGITS=${OPTARG}
			;;
		f)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -f is set to $OPTARG."
			EDA_CREDENTIAL_FILE=${OPTARG}
			;;
		g)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -g is set to $OPTARG."
			EDA_USER_GROUP=${OPTARG}
			;;
		k)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -k is set."
			DO_KILL=1
			;;
		m)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -m is set to $OPTARG."
			EDA_CONTAINER_PREFIX=${OPTARG}
			;;	
		l)
			[ $DEBUG = 1 ] && echo "[INFO] Flag -l is set to $OPTARG."
			EDA_USER_HOME=${OPTARG}
			;;
		h)
		 	echo
			echo "Spinning up Docker instances for EDA users (DIC@JKU)"
			echo
			echo "Usage: $0 [-h] [-d] [-c] [-k] [-p port_number] [-n number_instances] [-g user_group] [-s passwd_digits] [-f credential_file] [-l data_directory] [-m cont_prefix]"
			echo
			echo "       -h shows a help screen"
			echo "       -d enables the debug mode"
			echo "       -c cleans the user-file directories"
			echo "       -k stops and removes running containers"
			echo "       -p sets the starting port number (default $START_PORT)"
			echo "       -n sets the number of container instances that are generated (default $NUMBER_USERS)"
			echo "       -g sets the used group-ID (default $EDA_USER_GROUP)"
			echo "       -s sets the number of digits of the auto-generated user passwords (default $PASSWD_DIGITS)"
			echo "       -f sets the name of the credentials file (default $EDA_CREDENTIAL_FILE)"
			echo "       -l sets the directory of the user homes (default $EDA_USER_HOME)"
			echo "       -m sets the name prefix of the container (default $EDA_CONTAINER_PREFIX)"
			echo
			exit
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

# print a bit of status information
[ $DEBUG = 1 ] && [ $DO_CLEAN = 1 ] && echo "[INFO] Cleaning user directories is selected."
[ $DEBUG = 1 ] && [ $DO_KILL = 1 ] && echo "[INFO] Stopping and removing the running containers is selected."
[ $DEBUG = 1 ] && echo "[INFO] Starting port number is $START_PORT."
[ $DEBUG = 1 ] && echo "[INFO] User group is $EDA_USER_GROUP."
[ $DEBUG = 1 ] && echo "[INFO] User home directories located in $EDA_USER_HOME."
[ $DEBUG = 1 ] && echo "[INFO] Number of instances is $NUMBER_USERS."
[ $DEBUG = 1 ] && echo "[INFO] Number of password digits is $PASSWD_DIGITS."
[ $DEBUG = 1 ] && echo "[INFO] User credentials are stored in $EDA_CREDENTIAL_FILE."
[ $DEBUG = 1 ] && echo "[INFO] Container name prefix is $EDA_CONTAINER_PREFIX."

# here is a function for the actual work
_spin_up_server () {
	# $1 = username (e.g. user01)
	# $2 = passwd
	# $3 = webserver port (in the range of 50000-50200)

	DESIGNS=$(realpath "$EDA_USER_HOME/$1") && export DESIGNS
	export VNC_PW="$2"
	export CONTAINER_NAME="$EDA_CONTAINER_PREFIX-$1"
	export WEBSERVER_PORT="$3"
	export CONTAINER_GROUP="$EDA_USER_GROUP"

	if [ "$(docker ps -q -f name="${CONTAINER_NAME}")" ]; then
		if [ $DO_KILL = 0 ]; then
			echo "[ERROR] Running container instances detected without the -k option, exiting now!"
			exit 1
		fi
		[ $DEBUG = 1 ] && echo "[INFO] Container $CONTAINER_NAME running, will now stop and remove it!"
		docker stop "${CONTAINER_NAME}" > /dev/null
		docker rm "${CONTAINER_NAME}" > /dev/null
	fi

	if [ -d "$DESIGNS" ]; then
		if [ $DO_CLEAN = 1 ]; then
			rm -rf "$DESIGNS"
			mkdir -p "$DESIGNS"
		else
			echo "[ERROR] User directory $DESIGNS detected without the -c option, exiting now!"
			exit 1
		fi
	else
		mkdir -p "$DESIGNS"
	fi

	# now spinning up the EDA container using standard scripts
	# shellcheck source=/dev/null
	source start_vnc.sh
}

_write_credentials () {
	# $1 = username
	# $2 = passwd
	# $3 = webserver port
	# $4 = user data directory
	# $5 = credentials file

	# get the local IP of the server
	if [[ "$OSTYPE" == "linux"* ]]; then
		HOSTIP=$(hostname -I | awk '{print $1}')
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		HOSTIP=$(ipconfig getifaddr en0)
	else
		echo "[ERROR] Can not determine the IP address of host!"
		exit 1
	fi

	# write a JSON file
	jq ". + [{ \"user\": \"$1\", \"password\": \"$2\", \"port\": $3, \"url\": \"http://$HOSTIP:$3/?password=$2\", \"dockervm\": \"$EDA_CONTAINER_PREFIX-$1\", \"datadir\": \"$4\" }]" "$5" > "$5.tmp"
	mv "$5.tmp" "$5"
}

# sanitize input parameters
# check if parameters are integers
[ -n "$START_PORT" ] && [ "$START_PORT" -eq "$START_PORT" ] 2>/dev/null
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
   echo "[ERROR] -p requires an integer!"
   exit 1
fi
[ -n "$NUMBER_USERS" ] && [ "$NUMBER_USERS" -eq "$NUMBER_USERS" ] 2>/dev/null
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
   echo "[ERROR] -n requires an integer!"
   exit 1
fi
[ -n "$EDA_USER_GROUP" ] && [ "$EDA_USER_GROUP" -eq "$EDA_USER_GROUP" ] 2>/dev/null
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
   echo "[ERROR] -g requires an integer!"
   exit 1
fi
[ -n "$PASSWD_DIGITS" ] && [ "$PASSWD_DIGITS" -eq "$PASSWD_DIGITS" ] 2>/dev/null
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
   echo "[ERROR] -s requires an integer!"
   exit 1
fi
# check if parameters are in a useful range
if [ "$START_PORT" -lt 1024 ] || [ "$START_PORT" -gt 65535 ]; then
	echo "[ERROR] Illegal starting port number (range is 1024...65535)!"
	exit 1
fi
if [ "$NUMBER_USERS" -lt 1 ] || [ "$NUMBER_USERS" -gt 200 ]; then
	echo "[ERROR] Illegal number of container instances (must be between 1 and 200)!"
	exit 1
fi
if [ "$PASSWD_DIGITS" -lt 6 ] || [ "$PASSWD_DIGITS" -gt 64 ]; then
	echo "[ERROR] Illegal number of password digits (must be between 6 and 64)!"
	exit 1
fi
if [[ "$OSTYPE" == "linux"* ]]; then
	if [ -z "$(getent group "$EDA_USER_GROUP")" ]; then
		echo "[ERROR] Illegal user group!"
	exit 1
	fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
	if [ -z "$(dscacheutil -q group -a gid "$EDA_USER_GROUP")" ]; then
		echo "[ERROR] Illegal user group!"
	exit 1	
	fi
else
		echo "[ERROR] can not determine valid group ID!"
		exit 1
fi
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
echo "[]" > "$EDA_CREDENTIAL_FILE"

echo "[INFO] Starting EDA server instances."
for i in $(seq 1 "$NUMBER_USERS")
do
	# PASSWD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c"${1:-$PASSWD_DIGITS}")	
	# change the password generation to work also on macOS
	PASSWD=$(dd if=/dev/urandom bs=1 count=256 2>/dev/null | base64 | tr -c -d A-Za-z0-9 | head -c "$PASSWD_DIGITS")
	
	PORTNO=$((START_PORT + i - 1))
	USERNAME="u$PORTNO"

	[ $DEBUG = 1 ] && echo "[INFO] Creating container with user=$USERNAME, using port=$PORTNO, with password=$PASSWD."
	
	_write_credentials $USERNAME "$PASSWD" $PORTNO "$EDA_USER_HOME/$USERNAME" "$EDA_CREDENTIAL_FILE"
	_spin_up_server "$USERNAME" "$PASSWD" "$PORTNO"
done

echo
echo "[INFO] EDA containers are up and running!"
echo "[INFO] User credentials can be found in <$EDA_CREDENTIAL_FILE>."
echo "[DONE] Bye!"
