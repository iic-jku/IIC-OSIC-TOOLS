#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test the FPGA place-and-route flows: synthesize the same blinky for every
# supported FPGA family and check that a bitstream comes out.
#
# iCE40, ECP5 and Gowin run end to end in seconds. Xilinx 7-series is checked
# only up to synthesis plus a tool inventory, because nextpnr-xilinx needs a
# per-part chip database that takes minutes to generate and is kept out of the
# image on purpose (it is built once per part in the design, not per image).

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/32

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# $1 = label, $2 = expected artifact, $3.. = command
run_step() {
    local label=$1 artifact=$2
    shift 2
    if ! "$@" > "$WORKDIR/${label}.log" 2>&1; then
        echo "[ERROR] ${label} failed"
        tail -20 "$WORKDIR/${label}.log"
        ERROR=1
        return 1
    fi
    if [ ! -s "$WORKDIR/${artifact}" ]; then
        echo "[ERROR] ${label} produced no ${artifact}"
        ERROR=1
        return 1
    fi
    return 0
}

# Lattice iCE40: yosys -> nextpnr-ice40 -> icepack
# ------------------------------------------------
run_step ice40-synth ice40.json \
    yosys -p "synth_ice40 -dsp -spram -top blinky; write_json $WORKDIR/ice40.json" "$DIR/blinky.v" \
 && run_step ice40-pnr ice40.asc \
    nextpnr-ice40 --up5k --package sg48 --pcf-allow-unconstrained \
        --json "$WORKDIR/ice40.json" --pcf "$DIR/blinky.pcf" --asc "$WORKDIR/ice40.asc" \
 && run_step ice40-pack ice40.bin \
    icepack "$WORKDIR/ice40.asc" "$WORKDIR/ice40.bin"

# Lattice ECP5: yosys -> nextpnr-ecp5 -> ecppack
# -----------------------------------------------
run_step ecp5-synth ecp5.json \
    yosys -p "synth_ecp5 -top blinky; write_json $WORKDIR/ecp5.json" "$DIR/blinky.v" \
 && run_step ecp5-pnr ecp5.config \
    nextpnr-ecp5 --85k --package CABGA381 --lpf-allow-unconstrained \
        --json "$WORKDIR/ecp5.json" --lpf "$DIR/blinky.lpf" --textcfg "$WORKDIR/ecp5.config" \
 && run_step ecp5-pack ecp5.bit \
    ecppack "$WORKDIR/ecp5.config" "$WORKDIR/ecp5.bit" --compress

# Gowin: yosys -> nextpnr-himbaechel -> gowin_pack
# ------------------------------------------------
run_step gowin-synth gowin.json \
    yosys -p "synth_gowin -top blinky; write_json $WORKDIR/gowin.json" "$DIR/blinky.v" \
 && run_step gowin-pnr gowin_pnr.json \
    nextpnr-himbaechel --device GW1NR-LV9QN88PC6/I5 --vopt family=GW1N-9C \
        --vopt cst="$DIR/blinky.cst" \
        --json "$WORKDIR/gowin.json" --write "$WORKDIR/gowin_pnr.json" \
 && run_step gowin-pack gowin.fs \
    gowin_pack -d GW1N-9C -o "$WORKDIR/gowin.fs" "$WORKDIR/gowin_pnr.json"

# Xilinx 7-series (openXC7): synthesis plus a tool inventory
# ----------------------------------------------------------
run_step xilinx-synth xilinx.json \
    yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top blinky; write_json $WORKDIR/xilinx.json" "$DIR/blinky.v"

for tool in nextpnr-xilinx bbasm xc7frames2bit fasm2frames; do
    if ! command -v "$tool" > /dev/null; then
        echo "[ERROR] ${tool} is not on PATH"
        ERROR=1
    fi
done

if ! python3 -c "import prjxray, fasm" > /dev/null 2>&1; then
    echo "[ERROR] the prjxray and fasm Python modules are not importable"
    ERROR=1
fi

for var in NEXTPNR_XILINX_PYTHON_DIR PRJXRAY_DB_DIR; do
    if [ ! -d "${!var}" ]; then
        echo "[ERROR] ${var} is unset or does not point at a directory: ${!var}"
        ERROR=1
    fi
done

if [ ! -s "${NEXTPNR_XILINX_PYTHON_DIR}/bbaexport.py" ]; then
    echo "[ERROR] bbaexport.py is missing, the chipdb of a part cannot be generated"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <FPGA place-and-route flows> FAILED."
    exit 1
else
    echo "[INFO] Test <FPGA place-and-route flows> passed."
fi

# Cleanup
rm -f -- "$WORKDIR"/*.json "$WORKDIR"/*.asc "$WORKDIR"/*.config
exit 0
