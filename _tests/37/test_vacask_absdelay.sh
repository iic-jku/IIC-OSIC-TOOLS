#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that absdelay() delays in VACASK.
#
# absdelay() is only described by OSDI 0.5 modules. OpenVAF-reloaded master
# emits OSDI 0.4, and VACASK then treats every delay as zero without a warning:
# an ideal line becomes a through (see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/375). So this checks that the
# compiler vacask finds and the tline_ideal model shipped with VACASK are
# OSDI 0.5, that vacask finds the compiler without $TOOLS/bin on PATH, and that
# a matched tline_ideal delays a 250 MHz sine by 1 ns in tran and ac.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/37

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

VACASK=$(readlink -f "$(command -v vacask)")
MODDIR=$(dirname "$VACASK")/../lib/vacask/mod

# 1. vacask compiles a .va file when $TOOLS/bin is not on PATH.
cat > compile.sim << 'EOF'
absdelay compile check

ground 0
load "vdelay.va"

model vsrc vsource
model dly vdelay td=1n

v1 (in 0) vsrc dc=1
dly1 (out in) dly

control
  analysis op1 op
endc

embed "vdelay.va" <<<FILE
`include "disciplines.vams"

module vdelay(out, in);
    inout out, in;
    electrical out, in;
    branch (out) br_out;
    parameter real td = 1n from (0:inf);
    analog V(br_out) <+ absdelay(V(in), td);
endmodule
>>>FILE
EOF
if ! env PATH=/usr/bin:/bin "$VACASK" --no-output compile.sim > compile.log 2>&1; then
    echo "[ERROR] vacask cannot compile a .va file without \$TOOLS/bin on PATH:"
    grep -A1 -i -E "error|not found" compile.log | head -4
    ERROR=1
fi

# 2. The compiled module and the shipped tline_ideal are OSDI 0.5 or newer.
for osdi in vdelay.osdi "$MODDIR/tline_ideal.osdi"; do
    if [ ! -f "$osdi" ]; then
        echo "[ERROR] $osdi not found."
        ERROR=1
        continue
    fi
    VERSION=$(python3 -c '
import ctypes, sys
lib = ctypes.CDLL(sys.argv[1])
print("%d.%d" % (ctypes.c_uint32.in_dll(lib, "OSDI_VERSION_MAJOR").value,
                 ctypes.c_uint32.in_dll(lib, "OSDI_VERSION_MINOR").value))' "$(readlink -f "$osdi")" 2>&1)
    if awk -v v="$VERSION" 'BEGIN {split(v, p, "."); exit !(p[1] > 0 || p[2] >= 5)}'; then
        [ "$DEBUG" = 1 ] && echo "[INFO] $(basename "$osdi") is OSDI $VERSION."
    else
        echo "[ERROR] $(basename "$osdi") is OSDI '$VERSION', absdelay() needs OSDI 0.5."
        ERROR=1
    fi
done

# 3. A matched 50 Ohm line with td=1n delays a 250 MHz sine by a quarter period.
cat > tline.sim << 'EOF'
tline_ideal delay check

ground 0
load "resistor.osdi"
load "tline_ideal.osdi"

model resistor resistor
model vsrc vsource
model tl tline_ideal

v1 (s 0) vsrc type="sine" sinedc=0 ampl=1 freq=250M mag=1
rs (s a) resistor r=50
t1 (a 0 b 0) tl z0=50 td=1n
rl (b 0) resistor r=50

control
  abort always
  analysis ac1 ac from=250M to=250M mode="lin" points=1
  analysis tran1 tran stop=4n step=10p maxstep=10p
  postprocess(PYTHON, "check.py")
endc

embed "check.py" <<<FILE
import numpy as np
from vacask.rawfile import rawread
ac = rawread("ac1.raw").get()
print("PHASE %.3f" % np.degrees(np.angle(ac["b"][0] / ac["a"][0])))
tran = rawread("tran1.raw").get()
t, va, vb = tran["time"], tran["a"], tran["b"]
# V(b) stays zero until the wave arrives, then follows V(a) 1 ns later
print("EARLY %.6f" % np.max(np.abs(vb[t < 0.9e-9])))
late = t > 1.1e-9
print("LATE %.6f" % np.max(np.abs(vb[late] - np.interp(t[late] - 1e-9, t, va))))
>>>FILE
EOF
vacask --quiet-progress tline.sim > tline.log 2>&1 || ERROR=1
PHASE=$(awk '/^PHASE / {print $2}' tline.log)
EARLY=$(awk '/^EARLY / {print $2}' tline.log)
LATE=$(awk '/^LATE / {print $2}' tline.log)
[ "$DEBUG" = 1 ] && echo "[INFO] ac phase V(b)/V(a) $PHASE deg, tran |V(b)| before arrival $EARLY V, tran delay error $LATE V"
if ! awk -v p="$PHASE" 'BEGIN {exit !(p != "" && p > -91 && p < -89)}'; then
    echo "[ERROR] ac phase of V(b)/V(a) is '$PHASE' deg, expected -90 deg."
    ERROR=1
fi
if ! awk -v e="$EARLY" 'BEGIN {exit !(e != "" && e < 1e-3)}'; then
    echo "[ERROR] tran |V(b)| before the wave arrives is '$EARLY' V, expected 0 V."
    ERROR=1
fi
if ! awk -v l="$LATE" 'BEGIN {exit !(l != "" && l < 1e-2)}'; then
    echo "[ERROR] tran V(b) differs from V(a) delayed by 1 ns by '$LATE' V."
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <VACASK absdelay> FAILED."
    exit 1
else
    echo "[INFO] Test <VACASK absdelay> passed."
fi

# Cleanup
rm -f -- "$WORKDIR"/*.raw "$WORKDIR"/*.py
exit 0
