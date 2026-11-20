#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that LibreLane runs an OpenROAD with Python support (`openroad -python`,
# used by its Odb steps) when started without the librelane wrapper, e.g. via
# `python3 -m librelane` or the Python API (issue #453).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/50
LOG="$WORKDIR"/test.log

mkdir -p "$WORKDIR"

# Ask LibreLane itself which binary its Odb steps start, as they do outside the wrapper
OPENROAD_BIN=$(python3 -c "from librelane.steps.odb import OdbpyStep; print(OdbpyStep.get_openroad_path())" 2> "$LOG") || ERROR=1
[ "${DEBUG:-0}" = "1" ] && echo "[INFO] LibreLane uses OpenROAD <$OPENROAD_BIN>."

cat > "$WORKDIR"/odb_check.py << 'PYEOF'
import odb
print("ODB_PYTHON_OK", odb.dbDatabase.create() is not None)
PYEOF

if [ $ERROR -eq 0 ]; then
    (cd "$WORKDIR" && "$OPENROAD_BIN" -exit -no_splash -python "$WORKDIR"/odb_check.py) >> "$LOG" 2>&1 || ERROR=1
    grep -q "ODB_PYTHON_OK True" "$LOG" || ERROR=1
fi

[ "${DEBUG:-0}" = "1" ] && cat "$LOG"

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <LibreLane OpenROAD with Python> FAILED."
    exit 1
else
    echo "[INFO] Test <LibreLane OpenROAD with Python> passed."
    exit 0
fi
