#!/bin/sh
# ========================================================================
# DFFRAM Installation Script (optimized for IIC-OSIC-TOOLS)
#
# SPDX-FileCopyrightText: 2022 Harald Pretl
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
# Usage: iic-dffram-install.sh [install_dir]
#
# This script installs the DFFRAM package from GitHub at
# https://github.com/AUCOHL/DFFRAM
# ========================================================================

ERR_PARAM=1

if [ $# -gt 1 ]; then
	echo
	echo "DFFRAM installation script (IIC@JKU)"
	echo
	echo "Usage: $0 [install_dir]"
	echo
	echo "       If no <install_dir> is provided then <dffram> is used as default."
	echo
	exit $ERR_PARAM
fi

if [ $# = 1 ]; then
	DIR_NAME=$1
else
	DIR_NAME=dffram
fi

if [ ! -d "$DIR_NAME" ]; then
	git clone --depth 1 https://github.com/Cloud-V/DFFRAM "$DIR_NAME"
else
	echo "[INFO] Directory <$DIR_NAME> already exists."
fi

cd "$DIR_NAME" || exit

echo "[DONE] Bye!"
