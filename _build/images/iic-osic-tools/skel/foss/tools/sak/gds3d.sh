#!/bin/bash
# ========================================================================
# GDS3D wrapper script
#
# SPDX-FileCopyrightText: 2022 Georg Zachl
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
# ========================================================================

if [ $# = 1 ]; then
    GDS3D -p "$PDKPATH/libs.tech/gds3d/gds3d_tech.txt" -i "$1"
elif [ $# = 0 ]; then
    GDS3D -h
else
    GDS3D -p "$PDKPATH/libs.tech/gds3d/gds3d_tech.txt" "$@"
fi
