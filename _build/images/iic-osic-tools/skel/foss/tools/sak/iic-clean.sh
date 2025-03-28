#!/bin/sh
# ========================================================================
# Cleanup of temporary files
#
# SPDX-FileCopyrightText: 2021-2023 Harald Pretl
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
# Usage: iic-clean.sh [dir]
#
#        If [dir] is given then this directory is cleaned, otherwise
#        then the current directory is used.
# ========================================================================

if [ $# -eq 0 ]; then
    DIR=$PWD
else
    DIR=$1
fi

echo "[INFO] Cleaning up files (hierarchically) in $DIR."

find "$DIR" -name '*.spc' -exec rm {} \;
find "$DIR" -name '*.ext' -exec rm {} \;
find "$DIR" -name '*.log' -exec rm {} \;
find "$DIR" -name '*.out' -exec rm {} \;
find "$DIR" -name '*.raw' -exec rm {} \;
find "$DIR" -name '*.spice' -exec rm {} \;
find "$DIR" -name '*.vcd' -exec rm {} \;
find "$DIR" -name '*.xml' -exec rm {} \;
find "$DIR" -name 'ext*.tcl' -exec rm {} \;
find "$DIR" -name 'drc*.tcl' -exec rm {} \;
find "$DIR" -name 'pex*.tcl' -exec rm {} \;
find "$DIR" -name '*.rpt' -exec rm {} \;
