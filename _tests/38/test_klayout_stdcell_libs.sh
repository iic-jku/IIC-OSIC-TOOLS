#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that the LV and HV standard cells of both IHP PDKs show up as KLayout
# libraries (Instance dialog). The PDKs register them through autorun macros,
# and the LV macros were once lost from the PDK branch the image builds from
# (https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/374).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/38
LOG=$WORKDIR/klayout_stdcell_libs.log

mkdir -p "$WORKDIR"
: > "$LOG"

for pdk in ihp-sg13g2 ihp-sg13cmos5l; do
    # Subshell, so the PDK environment does not leak into the next PDK.
    (
        # shellcheck source=/dev/null
        source sak-pdk-script.sh "$pdk" > /dev/null
        # -zz instead of -b: -b skips the autorun macros under test.
        klayout -zz -r "$DIR/check_stdcell_libs.py"
    ) >> "$LOG" 2>&1 || ERROR=1
done

if [ "${DEBUG:-0}" = "1" ]; then
    cat "$LOG"
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <KLayout standard-cell libraries of the IHP PDKs> FAILED. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <KLayout standard-cell libraries of the IHP PDKs> passed."
    exit 0
fi
