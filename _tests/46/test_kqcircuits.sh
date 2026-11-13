#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/46
LOG=$WORKDIR/kqcircuits.log

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1
export QT_QPA_PLATFORM=offscreen
export MPLBACKEND=Agg
export MPLCONFIGDIR="$WORKDIR/matplotlib"

ERROR=0
python3 "$DIR/check_kqcircuits.py" > "$LOG" 2>&1 || ERROR=1
if [ "${DEBUG:-0}" = "1" ]; then
    cat "$LOG"
fi

if [ "$ERROR" -ne 0 ]; then
    echo "[ERROR] Test <KQCircuits standalone export> FAILED. Check $LOG for details."
    exit 1
fi
echo "[INFO] Test <KQCircuits standalone export> passed."
