#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the riscv64-unknown-elf tools

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test if a command finishes successfully
test() {
    local cmd="$1"
    echo "Running: $cmd"
    eval "$cmd" &>> "$LOG"
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "[ERROR] '$cmd' failed" >> "$LOG"
    fi
    echo -e "\n\n\n" >> "$LOG"
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


TMP=/foss/designs/runs/${RAND}/09
LOG=/foss/designs/runs/${RAND}/09/riscv_elf_tools.log
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$TMP"

cp "$DIR/crt0.S"   "$TMP/"
cp "$DIR/link.ld"  "$TMP/"
cp "$DIR/main.c"   "$TMP/"
cp "$DIR/hello.c"  "$TMP/"
cd "$TMP" || exit

RISCV_PREFIX=riscv64-unknown-elf
RISCV_CC=$RISCV_PREFIX-gcc
RISCV_FLAGS="-march=rv32i -mabi=ilp32  -mcmodel=medany -static -ffast-math"

[ $DEBUG -eq 1 ] && echo "[INFO] Testing riscv64-unknown-elf tools..."
{
    test "$RISCV_CC $RISCV_FLAGS -c main.c -o main.o"
    test "$RISCV_CC $RISCV_FLAGS -c crt0.S -o crt0.o"
    test "$RISCV_CC $RISCV_FLAGS -nostartfiles -lm -lgcc -Tlink.ld -o main.elf main.o crt0.o"
    test "$RISCV_CC -o hello hello.c"
    test "spike pk hello"
} &> "$LOG"

if grep -q "\[ERROR\]" "$LOG"; then
    echo "[ERROR] Test <riscv64-unknown-elf toolchain> FAILED! Check log at <$LOG>."
    exit 1
else
    echo "[INFO] Test <riscv64-unknown-elf toolchain> passed."
    exit 0
fi
