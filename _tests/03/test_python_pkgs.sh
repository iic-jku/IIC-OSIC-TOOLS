#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if a few of the import Python packages work properly.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERR=0

if ! python "$DIR/pkgs.py" 
then
    echo "[ERROR] Test <Loading Python-packages> FAILED."
    ERR=1
else
    echo "[INFO] Test <Loading Python-packages> passed."
fi

if ! /foss/tools/charlib/bin/python -c "import charlib"
then
    echo "[ERROR] Test <Loading charlib> FAILED."
    ERR=1
else
    echo "[INFO] Test <Loading charlib> passed."
fi

if ! /foss/tools/vlsirtools/bin/python -c "import hdl21"
then
    echo "[ERROR] Test <Loading hdl21> FAILED."
    ERR=1
else
    echo "[INFO] Test <Loading hdl21> passed."
fi

# Clean up log file created by najaeda import
rm -f naja_perf.log

exit $ERR
