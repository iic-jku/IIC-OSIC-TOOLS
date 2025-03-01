#!/bin/bash
# SPDX-FileCopyrightText: 2024 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if the OpenROAD flow scripts (ORFS) run successfully; we run
# this for IHP SG13G2 only

RESULT=/tmp/result_orfs_sg13g2.log
WORK_DIR=/tmp/orfs_sg13g2
FLOW_HOME=$WORK_DIR/orfs/flow

mkdir -p $WORK_DIR && cd $WORK_DIR || exit 1
git clone --quiet --filter=blob:none https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git orfs
cd orfs || exit 1
ORFS_COMMIT=$(cat "$TOOLS/openroad-latest/ORFS_COMMIT")
git checkout --quiet "$ORFS_COMMIT"
cd $FLOW_HOME || exit 1

# prepare environment for ORFS
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad-latest/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad-latest/bin/sta
export FLOW_HOME

# FIXME this is needed to run flow w/o errors
export GDS_ALLOW_EMPTY=spi_DEF_FILL

# run ORFS with IHP130 SG13G2
export DESIGN_CONFIG=./designs/ihp-sg13g2/spi/config.mk
make > $RESULT

# check if there is an error in the log
if grep -q "ERROR" "$RESULT"; then
    echo "[ERROR] Test <ORFS with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <ORFS with ihp-sg13g2> passed."
    exit 0
fi
