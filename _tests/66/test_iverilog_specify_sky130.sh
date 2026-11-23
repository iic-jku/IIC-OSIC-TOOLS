#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that Icarus Verilog elaborates and simulates a flip-flop of the sky130
# HD standard cells with specify blocks enabled (-gspecify), as an SDF
# gate-level simulation does.
#
# The cell declares $setuphold and $recrem with timestamp/timecheck
# conditions, which iverilog rejected under -gspecify until PR 1883
# (steveicarus/iverilog#1871). Since then they are a warning.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}
ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/66

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

cat > tb.v << 'EOF2'
`timescale 1ns/1ps
module tb;
  reg clk = 0, d = 0, rst = 0;
  wire q;
  sky130_fd_sc_hd__dfrtp_1 u (.Q(q), .D(d), .RESET_B(rst), .CLK(clk),
                              .VPWR(1'b1), .VGND(1'b0), .VPB(1'b1), .VNB(1'b0));
  always #5 clk = ~clk;
  initial begin #12 rst = 1; d = 1; #20 $display("Q=%b", q); $finish; end
endmodule
EOF2

lib="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
if ! iverilog -gspecify -DUSE_POWER_PINS -o sky130.vvp tb.v "$lib/primitives.v" "$lib/sky130_fd_sc_hd.v" > sky130.log 2>&1; then
    echo "[ERROR] iverilog -gspecify cannot elaborate sky130_fd_sc_hd__dfrtp_1, see <$WORKDIR/sky130.log>."
    ERROR=1
elif ! vvp -n sky130.vvp 2>&1 | tee -a sky130.log | grep -q "^Q=1$"; then
    echo "[ERROR] sky130_fd_sc_hd__dfrtp_1 does not capture D=1 in the simulation, see <$WORKDIR/sky130.log>."
    ERROR=1
elif [ "$DEBUG" = 1 ]; then
    echo "[INFO] sky130_fd_sc_hd__dfrtp_1 elaborates and simulates with -gspecify."
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <iverilog -gspecify with the sky130 standard cells> FAILED."
    exit 1
else
    echo "[INFO] Test <iverilog -gspecify with the sky130 standard cells> passed."
    exit 0
fi
