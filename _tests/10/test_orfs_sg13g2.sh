#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the OpenROAD flow scripts (ORFS) run successfully; we run
# this for IHP SG13G2 only

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

WORK_DIR=${RUNS_DIR}/${RAND}/10
RESULT=${RUNS_DIR}/${RAND}/10/result_orfs_sg13g2.log
STDERR_LOG=${RUNS_DIR}/${RAND}/10/result_orfs_sg13g2.stderr.log
FLOW_HOME=$WORK_DIR/orfs/flow

mkdir -p "$WORK_DIR" && cd "$WORK_DIR" || exit 1
git clone --quiet --filter=blob:none https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git orfs > /dev/null 2>&1
cd orfs || exit 1
ORFS_COMMIT=$(cat "$TOOLS/openroad/ORFS_COMMIT")
git checkout --quiet "$ORFS_COMMIT" > /dev/null 2>&1
cd "$FLOW_HOME" || exit 1

# prepare environment for ORFS
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad/bin/sta
export FLOW_HOME

# run ORFS with IHP130 SG13G2
export DESIGN_CONFIG=./designs/ihp-sg13g2/spi/config.mk
# stderr goes into its own log: ORFS reports the per-step runtime there, which
# would otherwise leak onto the console shared by all tests running in parallel
make > "$RESULT" 2> "$STDERR_LOG"

# check if there is an error in the log
if grep -q "ERROR" "$RESULT"; then
    echo "[ERROR] Test <ORFS with ihp-sg13g2> FAILED. Check the logs <$RESULT> and <$STDERR_LOG>."
    exit 1
else
    echo "[INFO] Test <ORFS with ihp-sg13g2> passed."
    exit 0
fi
