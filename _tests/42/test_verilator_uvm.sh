#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that Verilator builds and runs a UVM test with the UVM library shipped
# in $UVM_HOME (see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/156).
# A minimal uvm_test is built with --binary against the package without DPI and
# against the package with DPI (plus its C sources through --vpi), then run.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/42

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

if [ -z "${UVM_HOME}" ] || [ ! -f "${UVM_HOME}/uvm_pkg_nodpi.svh" ]; then
    echo "[ERROR] UVM_HOME is unset or holds no UVM package (UVM_HOME=${UVM_HOME})."
    echo "[ERROR] Test <Verilator with UVM> FAILED."
    exit 1
fi

cat > tb.sv << 'EOF'
module tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  // verilator lint_off WIDTHTRUNC
  class hello_test extends uvm_test;
    `uvm_component_utils(hello_test)
    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      `uvm_info("HELLO", "UVM is alive", UVM_LOW)
      phase.drop_objection(this);
    endtask
    function void report_phase(uvm_phase phase);
      $display("** UVM TEST PASSED **");
    endfunction
  endclass
  initial run_test("hello_test");
endmodule
EOF

run_variant() {
    local variant=$1
    shift
    if verilator --binary -j 0 --CFLAGS -O0 --top-module tb -Mdir "obj_$variant" "+incdir+${UVM_HOME}" "$@" tb.sv > "build_$variant.log" 2>&1 && [ -x "obj_$variant/Vtb" ]; then
        "obj_$variant/Vtb" +UVM_NO_RELNOTES > "run_$variant.log" 2>&1 || ERROR=1
        if ! grep -q "UVM is alive" "run_$variant.log" || ! grep -q "UVM TEST PASSED" "run_$variant.log"; then
            echo "[ERROR] UVM test ($variant) did not run to the report phase:"
            tail -4 "run_$variant.log"
            ERROR=1
        elif [ "$DEBUG" = "1" ]; then
            echo "[INFO] UVM test ($variant) passed."
        fi
    else
        echo "[ERROR] Verilator cannot build the UVM test ($variant):"
        grep -m 4 -E "%Error|error:" "build_$variant.log" || tail -4 "build_$variant.log"
        ERROR=1
    fi
}

run_variant nodpi "${UVM_HOME}/uvm_pkg_nodpi.svh"
run_variant dpi --vpi "${UVM_HOME}/uvm_pkg_dpi.svh" "${UVM_HOME}/dpi/uvm_dpi.cc"

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <Verilator with UVM> FAILED."
    exit 1
else
    echo "[INFO] Test <Verilator with UVM> passed."
    exit 0
fi
