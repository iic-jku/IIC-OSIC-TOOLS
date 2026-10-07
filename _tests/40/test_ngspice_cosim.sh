#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test ngspice mixed-signal co-simulation (d_cosim) with Icarus Verilog (ivlng)
# and Verilator (vlnggen).
#
# Both broke in images up to 2026.05 (see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/287): ivlng.so failed with
# "undefined symbol: Cosim_setup", and Verilator libraries failed on an ngspice
# bug fixed in ngspice-47. A clocked 2-bit counter is run in d_cosim with both
# simulators, and its value is checked after each clock edge.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/40

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Without a timescale Icarus counts in 1 s units and never sees the us edges.
cat > cnt.v << 'EOF'
`timescale 1ns/1ps
module cnt(input clk, output reg [1:0] q);
  initial q = 0;
  always @(posedge clk) q <= q + 1;
endmodule
EOF

# Rising clock edges at 1, 11, 21, 31 and 41 us. The counter is sampled 5 us
# after each edge, and its value is read back through dac_bridge. d_cosim lists
# the bits of a vector port MSB first.
SAMPLES=(6 16 26 36 46)
EXPECTED=(1 2 3 0 1)

# $1: netlist, $2: .model line of the d_cosim instance
write_bench() {
    cat > "$1" << EOF
* d_cosim counter
Vclk clk 0 PULSE(0 1.8 1u 10n 10n 5u 10u)
aadc [clk] [dclk] adc1
.model adc1 adc_bridge(in_low=0.9 in_high=0.9)
adut [dclk] [q1 q0] null dut
$2
adac [q0 q1] [a0 a1] dac1
.model dac1 dac_bridge(out_low=0 out_high=1.8)
.control
tran 100n 50u
let n = v(a0)/1.8 + 2*v(a1)/1.8
EOF
    for t in "${SAMPLES[@]}"; do
        echo "meas tran n$t find n at=${t}u" >> "$1"
    done
    cat >> "$1" << 'EOF'
quit
.endc
.end
EOF
}

# $1: simulator name, $2: netlist, $3: log
check_counter() {
    ngspice -b "$2" > "$3" 2>&1
    if grep -q -i -E "undefined symbol|no entry function|error" "$3"; then
        echo "[ERROR] d_cosim with $1 failed:"
        grep -i -E "undefined symbol|no entry function|error" "$3" | head -4
        ERROR=1
        return
    fi
    local i t got
    for i in "${!SAMPLES[@]}"; do
        t=${SAMPLES[$i]}
        got=$(sed -n "s/^n$t *= *\([-0-9.e+]*\).*/\1/p" "$3" | head -1)
        if [ -z "$got" ] || ! awk -v g="$got" -v e="${EXPECTED[$i]}" 'BEGIN { exit !(g > e - 0.1 && g < e + 0.1) }'; then
            echo "[ERROR] d_cosim counter with $1 reads ${got:-nothing} at $t us, expected ${EXPECTED[$i]}."
            ERROR=1
        elif [ "$DEBUG" = "1" ]; then
            echo "[INFO] d_cosim counter with $1 reads $got at $t us."
        fi
    done
}

# 1. Icarus Verilog through ivlng.so and ivlng.vpi
if iverilog -o cnt cnt.v > iverilog.log 2>&1; then
    write_bench tb_icarus.cir '.model dut d_cosim simulation="ivlng" sim_args=["cnt"]'
    check_counter "Icarus Verilog" tb_icarus.cir icarus.log
else
    echo "[ERROR] iverilog cannot compile the counter:"
    head -4 iverilog.log
    ERROR=1
fi

# 2. Verilator through a library built by ngspice's vlnggen script
if ngspice vlnggen cnt.v > vlnggen.log 2>&1 && [ -f cnt.so ]; then
    write_bench tb_verilator.cir '.model dut d_cosim simulation="./cnt.so"'
    check_counter "Verilator" tb_verilator.cir verilator.log
else
    echo "[ERROR] vlnggen cannot build the counter library:"
    tail -4 vlnggen.log
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <ngspice co-simulation with Icarus Verilog and Verilator> FAILED."
    exit 1
else
    echo "[INFO] Test <ngspice co-simulation with Icarus Verilog and Verilator> passed."
    exit 0
fi
