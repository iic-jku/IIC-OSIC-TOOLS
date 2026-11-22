#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that Icarus Verilog elaborates and simulates a flip-flop of the IHP
# standard-cell libraries with specify blocks enabled (-gspecify), as an SDF
# gate-level simulation does.
#
# The cells declare $setuphold and $recrem with delayed reference and data
# signals. steveicarus/iverilog PR 1743 ($recrem) and PR 1745 ($setuphold)
# rejected them under -gspecify until PR 1875 (steveicarus/iverilog#1871).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}
ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/52

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

cat > tb.v << 'EOF'
module tb;
  reg clk = 0, d = 0, rst = 0;
  wire q, qn;
  `CELL u (.Q(q), .Q_N(qn), .D(d), .RESET_B(rst), .CLK(clk));
  always #5 clk = ~clk;
  initial begin #12 rst = 1; d = 1; #20 $display("Q=%b", q); $finish; end
endmodule
EOF

for pdk in sg13g2 sg13cmos5l; do
    lib="$PDK_ROOT/ihp-$pdk/libs.ref/${pdk}_stdcell/verilog"
    srcs=("$lib/${pdk}_stdcell.v")
    [ -f "$lib/${pdk}_udp.v" ] && srcs+=("$lib/${pdk}_udp.v")
    if ! iverilog -gspecify -DCELL="${pdk}_dfrbp_1" -o "$pdk.vvp" tb.v "${srcs[@]}" > "$pdk.log" 2>&1; then
        echo "[ERROR] iverilog -gspecify cannot elaborate ${pdk}_dfrbp_1, see <$WORKDIR/$pdk.log>."
        ERROR=1
    elif ! vvp -n "$pdk.vvp" 2>&1 | tee -a "$pdk.log" | grep -q "^Q=1$"; then
        echo "[ERROR] ${pdk}_dfrbp_1 does not capture D=1 in the simulation, see <$WORKDIR/$pdk.log>."
        ERROR=1
    elif [ "$DEBUG" = 1 ]; then
        echo "[INFO] ${pdk}_dfrbp_1 elaborates and simulates with -gspecify."
    fi
done

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <iverilog -gspecify with the IHP standard cells> FAILED."
    exit 1
else
    echo "[INFO] Test <iverilog -gspecify with the IHP standard cells> passed."
    exit 0
fi
