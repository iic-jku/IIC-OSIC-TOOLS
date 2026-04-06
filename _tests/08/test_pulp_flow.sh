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
run_test() {
    local cmd="$1"
    echo "Running: $cmd"
    eval "$cmd" &>> "$LOG"
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "[ERROR] '$cmd' failed" >> "$LOG"
    fi
    echo -e "\n\n\n" >> "$LOG"
}

# test if a command fails
run_test_fail() {
    # shellcheck disable=SC2317
    local cmd="$1"
    # shellcheck disable=SC2317
    echo "Running: $cmd"
    # shellcheck disable=SC2317
    eval "$cmd" &>> "$LOG"
    # shellcheck disable=SC2317
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "[ERROR] '$cmd' was expected to fail but succeeded" >> "$LOG"
    else
        echo "[INFO] '$cmd' failed as expected" >> "$LOG"
    fi
    # shellcheck disable=SC2317
    echo -e "\n\n\n" >> "$LOG"
}

# if debug mode is enabled output is verbose, otherwise not
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

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP=/foss/designs/runs/${RAND}/08
LOG=/foss/designs/runs/${RAND}/08/pulp.log

mkdir -p "$TMP"

cp "$DIR"/Bender.yml "$TMP"/
cp "$DIR"/*.sv       "$TMP"/
cd "$TMP"/ || exit

[ $DEBUG -eq 1 ] && echo "[INFO] Testing bender..."
{
    run_test "bender update"
    run_test "bender checkout"
    run_test "bender script flist-plus -t test_target -D COMMON_CELLS_ASSERTS_OFF > sources.f"
    run_test "bender script flist-plus -D COMMON_CELLS_ASSERTS_OFF > sources_fail.f"
} >> "$LOG" 2>&1

[ $DEBUG -eq 1 ] && echo "[INFO] Testing yosys-slang..."
{
    run_test "yosys -Q -q -p \"plugin -i slang.so; read_slang --top top -F sources.f; synth;\""
    run_test_fail "yosys -Q -q -p \"plugin -i slang.so; read_slang --top top -F sources_fail.f; synth;\""
} >> "$LOG" 2>&1

if grep -q "\[ERROR\]" "$LOG"; then
    echo "[ERROR] Test <PULP-flow> FAILED! Check log at <$LOG>."
    exit 1
else
    echo "[INFO] Test <PULP-flow> passed."
    exit 0
fi
