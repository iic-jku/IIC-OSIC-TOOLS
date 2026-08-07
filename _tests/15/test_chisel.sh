#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test Chisel with a simple ALU example from Martin Schoeberl

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

TMP=${RUNS_DIR}/${RAND}/15
LOG=${RUNS_DIR}/${RAND}/15/chisel.log

mkdir -p "$TMP"

git clone --quiet --depth=1 https://github.com/schoeberl/chisel-examples.git "$TMP"
cd "$TMP" || exit 1

# sbt starts a background server (sbt-launch --detach-stdio) that outlives the
# client and stays resident until its idle timeout -- ~1 GB of JVM sitting in
# the container long after this test is done. All tests of the suite run
# concurrently, so that is memory taken away from the rest of the run (a klayout
# job has been OOM-killed next to it). Shut the server down on every exit path.
cleanup() {
    timeout 60 sbt shutdown >> "$LOG" 2>&1
    return 0
}
trap cleanup EXIT

eval "make alu-test" &> "$LOG"
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "[ERROR] Test <Chisel-test with ALU> FAILED. Check log <$LOG>."
    exit 1
else
    echo "[INFO] Test <Chisel-test with ALU> passed."
    exit 0
fi
