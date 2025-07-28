#!/bin/bash
# SPDX-FileCopyrightText: 2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the Icarus Verilog (iVerilog) tool

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

set -euo pipefail

if ! command -v iverilog >/dev/null 2>&1; then
    echo "[ERROR] iVerilog is not installed or not in PATH."
    exit 1
fi

TMP=/foss/designs/runs/${RAND}/12
LOG=/foss/designs/runs/${RAND}/12/test_iverilog.log

mkdir -p "$TMP"

SRC1="/foss/examples/demo_sky130A/dig/counter.v"
SRC2="/foss/examples/demo_sky130A/dig/counter_tb.v"

if [[ ! -f "$SRC1" ]]; then
    echo "[ERROR] Source file $SRC1 not found."
    exit 1
fi
if [[ ! -f "$SRC2" ]]; then
    echo "[ERROR] Source file $SRC2 not found."
    exit 1
fi

cp "$SRC1" "$TMP"
cp "$SRC2" "$TMP"
cd "$TMP" || { echo "[ERROR] Failed to change directory to $TMP."; exit 1; }

if ! iverilog -o counter_tb.vvp counter_tb.v; then
    echo "[ERROR] Compilation with iVerilog failed."
    exit 1
fi

if ! vvp counter_tb.vvp > "$LOG" 2>&1; then
    echo "[ERROR] Simulation with vvp failed. See <$LOG> for details."
    exit 1
fi

echo "[INFO] Test <iVerilog> passed."
exit 0
