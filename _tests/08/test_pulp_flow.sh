#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the following tools:
# - bender: https://github.com/pulp-platform/bender
# - sv2v:   https://github.com/zachjs/sv2v

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test if a command finishes successfully
test() {
    local cmd="$1"
    echo "Running: $cmd"
    eval "$cmd" &>> $LOG
    if [ $? -ne 0 ]; then
        echo "[ERROR] '$cmd' failed" >> $LOG
    fi
    echo -e "\n\n\n" >> $LOG
}

# test if a command fails
test_fail() {
    local cmd="$1"
    echo "Running: $cmd"
    eval "$cmd" &>> $LOG
    if [ $? -eq 0 ]; then
        echo "[ERROR] '$cmd' was expected to fail but succeeded" >> $LOG
    else
        echo "[INFO] '$cmd' failed as expected" >> $LOG
    fi
    echo -e "\n\n\n" >> $LOG
}

# if debug mode is enabled outout is verbose, otherwise not
DEBUG=0
while getopts "d" flag; do
	case $flag in
		d)
			echo "[INFO] DEBUG is enabled!"
			DEBUG=1
			;;
		*)
			;;
    esac
done
shift $((OPTIND-1))

TMP=/foss/designs/runs/${RAND}
LOG=/foss/designs/runs/${RAND}/pulp.log
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p $TMP

cp $DIR/Bender.yml $TMP/
cp $DIR/*.sv       $TMP/
cd $TMP/

[ $DEBUG -eq 1 ] && echo "[INFO] Testing bender..."
{
    test "bender update"
    test "bender checkout"
    test "bender sources -f > error.json"
    test "bender sources -f -t test_target > top.json"
} &> $LOG

[ $DEBUG -eq 1 ] && echo "[INFO] Testing sv2v..."
{
    test "sv2v --write top_sv2v.v top.sv"
    test "yosys -Q -q -p \"read_verilog top_sv2v.v; synth;\""
} &> $LOG

if grep -q "\[ERROR\]" $LOG; then
    echo "[ERROR] Test <PULP-flow> FAILED! Check log at <$LOG>."
    exit 1
else
    echo "[INFO] Test <PULP-flow> passed."
    exit 0
fi
