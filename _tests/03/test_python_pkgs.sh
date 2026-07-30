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

if ! python "$DIR/pyside6_files.py"
then
    echo "[ERROR] Test <PySide6 installation complete> FAILED."
    ERR=1
else
    echo "[INFO] Test <PySide6 installation complete> passed."
fi

if ! /foss/tools/charlib/bin/python -c "import charlib"
then
    echo "[ERROR] Test <Loading charlib> FAILED."
    ERR=1
else
    echo "[INFO] Test <Loading charlib> passed."
fi

# A bare "import charlib" passes even when CharLib is unusable, so exercise the
# PySpice API it actually needs. This catches the venv's pinned PySpice fork
# being shadowed by the system PySpice via the global PYTHONPATH.
if ! charlib_pyspice=$(env -u PYTHONPATH /foss/tools/charlib/bin/python -c \
    "import PySpice
assert PySpice.__file__.startswith('/foss/tools/charlib/'), PySpice.__file__
PySpice.Circuit('t')" 2>&1)
then
    echo "[ERROR] Test <charlib PySpice API> FAILED: ${charlib_pyspice}"
    ERR=1
else
    echo "[INFO] Test <charlib PySpice API> passed."
fi

# The charlib on PATH must be the wrapper that unsets PYTHONPATH, not a bare
# symlink into the venv (see install_links.sh).
if ! grep -q "unset PYTHONPATH" "$(command -v charlib)" 2>/dev/null
then
    echo "[ERROR] Test <charlib PYTHONPATH wrapper> FAILED."
    ERR=1
else
    echo "[INFO] Test <charlib PYTHONPATH wrapper> passed."
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
