#!/bin/sh
# ========================================================================
# DFFRAM Usage Script (optimized for IIC-OSIC-TOOLS)
#
# SPDX-FileCopyrightText: 2022-2023 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
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
#
# Usage: iic-dffram.sh [parameter list]
#
# This script provides a wrapper for the DFFRAM package from GitHub at
# https://github.com/AUCOHL/DFFRAM
# ========================================================================

ERR_NO_VAR=1
ERR_NO_DFFRAM=2

export NO_CHECK_INSTALL=1

if [ -z ${PDK_ROOT+x} ]; then
	echo "[ERROR] Environment variable PDK_ROOT not set!"
	exit $ERR_NO_VAR
fi

if [ -z ${OPENLANE_ROOT+x} ]; then
	echo "[ERROR] Environment variable OPENLANE_ROOT not set!"
	exit $ERR_NO_VAR
fi

if [ ! -f dffram.py ]; then
	echo "[ERROR] Script needs to be started in DFFRAM directory!"
	echo
	echo "[INFO] You can install DFFRAM using <iic-dffram-install.sh>."
	exit $ERR_NO_DFFRAM
fi

OPENLANE_DIR=$(realpath "$OPENLANE_ROOT"/*/)

if [ $# = 0 ]; then
	./dffram.py --using-local-openlane "$OPENLANE_DIR" --pdk-root "$PDK_ROOT" --help
else
	./dffram.py -j "$(nproc)" --using-local-openlane "$OPENLANE_DIR" --pdk-root "$PDK_ROOT" "$@"
fi

echo "[DONE] DFFRAM generated, bye!"
