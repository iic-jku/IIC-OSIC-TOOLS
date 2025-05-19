#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if a few of the import Python packages work properly.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! python "$DIR/pkgs.py" 
then
    echo "[ERROR] Test <Loading Python-packages> FAILED."
    exit 1
else
    echo "[INFO] Test <Loading Python-packages> passed."
    exit 0
fi
