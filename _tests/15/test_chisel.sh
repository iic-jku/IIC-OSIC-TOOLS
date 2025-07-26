#!/bin/bash
# SPDX-FileCopyrightText: 2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test Chisel with a simple ALU example from Martin Schoeberl

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

TMP=/foss/designs/runs/${RAND}
LOG=/foss/designs/runs/${RAND}/chisel.log

mkdir -p "$TMP"

git clone --quiet --depth=1 https://github.com/schoeberl/chisel-examples.git "$TMP"
cd "$TMP" || exit 1

eval "make alu-test" &> "$LOG"
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "[ERROR] Test <Chisel-test with ALU> FAILED. Check log <$LOG>."
    exit 1
else
    echo "[INFO] Test <Chisel-test with ALU> passed."
    exit 0
fi
