#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that Verilator builds and runs a model with FST tracing (--trace-fst).
#
# Since Verilator 5.052, verilated_fst_c.cpp includes <lz4.h>, so a user model
# built in the container failed with "lz4.h: No such file or directory" while
# liblz4-dev was installed in base-dev only (see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/393). A counter is built with
# --binary --trace-fst, run, and its value and FST dump are checked.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/41

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Rising clock edges at 5, 15, ..., 95 ns, so q is 10 when it is printed at 100 ns.
cat > cnt.sv << 'EOF'
`timescale 1ns/1ps
module tb;
  reg clk = 0;
  reg [3:0] q = 0;
  always #5 clk = ~clk;
  always @(posedge clk) q <= q + 1;
  initial begin
    $dumpfile("cnt.fst");
    $dumpvars(0, tb);
    #100 $display("q=%0d", q);
    $finish;
  end
endmodule
EOF

if verilator --binary --trace-fst --top-module tb -Mdir obj cnt.sv > build.log 2>&1 && [ -x obj/Vtb ]; then
    obj/Vtb > run.log 2>&1 || ERROR=1
    if ! grep -q "^q=10$" run.log; then
        echo "[ERROR] Verilator model prints $(grep "^q=" run.log || echo nothing), expected q=10."
        ERROR=1
    elif [ "$DEBUG" = "1" ]; then
        echo "[INFO] Verilator model prints q=10."
    fi
    if [ ! -s cnt.fst ]; then
        echo "[ERROR] Verilator model wrote no FST dump."
        ERROR=1
    elif command -v fst2vcd > /dev/null 2>&1; then
        # The FST must be readable and hold the counter signal.
        if ! fst2vcd cnt.fst 2> fst2vcd.log | grep -q -E "var .* q "; then
            echo "[ERROR] FST dump cannot be read back or lacks signal q:"
            head -4 fst2vcd.log
            ERROR=1
        fi
    else
        echo "[WARNING] fst2vcd not found, FST dump is not read back."
    fi
else
    echo "[ERROR] Verilator cannot build the model with --trace-fst:"
    grep -m 4 -E "error|Error" build.log || tail -4 build.log
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <Verilator with FST tracing> FAILED."
    exit 1
else
    echo "[INFO] Test <Verilator with FST tracing> passed."
    exit 0
fi
