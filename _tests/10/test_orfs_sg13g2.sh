#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the OpenROAD flow scripts (ORFS) run successfully; we run
# this for IHP SG13G2 only

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

WORK_DIR=/foss/designs/runs/${RAND}/10
RESULT=/foss/designs/runs/${RAND}/10/result_orfs_sg13g2.log
FLOW_HOME=$WORK_DIR/orfs/flow

mkdir -p "$WORK_DIR" && cd "$WORK_DIR" || exit 1
git clone --quiet --filter=blob:none https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git orfs > /dev/null 2>&1
cd orfs || exit 1
ORFS_COMMIT=$(cat "$TOOLS/openroad-latest/ORFS_COMMIT")
git checkout --quiet "$ORFS_COMMIT" > /dev/null 2>&1
cd "$FLOW_HOME" || exit 1

# prepare environment for ORFS
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad-latest/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad-latest/bin/sta
export FLOW_HOME

# FIXME this is needed to run flow w/o errors
export GDS_ALLOW_EMPTY=spi_DEF_FILL

# run ORFS with IHP130 SG13G2
export DESIGN_CONFIG=./designs/ihp-sg13g2/spi/config.mk
make > "$RESULT"

# check if there is an error in the log
if grep -q "ERROR" "$RESULT"; then
    echo "[ERROR] Test <ORFS with ihp-sg13g2> FAILED. Check the log <$RESULT>."
    exit 1
else
    echo "[INFO] Test <ORFS with ihp-sg13g2> passed."
    exit 0
fi
