#!/bin/bash
# SPDX-FileCopyrightText: 2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if a few of the import Python packages work properly.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! python "$DIR/pkgs.py" 
then
    echo "[ERROR] Test <Python-Packages> FAILED."
    exit 1
else
    echo "[INFO] Test <Python-Packages> passed."
    exit 0
fi
