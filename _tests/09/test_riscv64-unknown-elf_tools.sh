#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Smoke test for the riscv64-unknown-elf tools

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


TMP=/tmp/test_09
LOG=$TMP/tools.log
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


if [ -d $TMP ]; then
    rm -rf $TMP/*
else 
    mkdir $TMP
fi

cp $DIR/crt0.S     $TMP/
cp $DIR/link.ld    $TMP/
cp $DIR/main.c     $TMP/
cp $DIR/hello.c    $TMP/
cd $TMP/

RISCV_PREFIX=riscv64-unknown-elf
RISCV_CC=$RISCV_PREFIX-gcc
RISCV_lD=$RISCV_PREFIX-ld
RISCV_FLAGS="-march=rv32i -mabi=ilp32  -mcmodel=medany -static -ffast-math"

[ $DEBUG -eq 1 ] && echo "[INFO] Testing riscv64-unknown-elf tools..."
{
    test "$RISCV_CC $RISCV_FLAGS -c main.c -o main.o"
    test "$RISCV_CC $RISCV_FLAGS -c crt0.S -o crt0.o"
    test "$RISCV_CC $RISCV_FLAGS -nostartfiles -lm -lgcc -Tlink.ld -o main.elf main.o crt0.o"
    test "$RISCV_CC -o hello hello.c"
    test "spike pk hello"
} &> $LOG

if grep -q "\[ERROR\]" $LOG; then
    echo "[ERROR] Test <riscv64-unknown-elf toolchain> FAILED! Check log at <$LOG>."
    exit 1
else
    echo "[INFO] Test <riscv64-unknown-elf toolchain> passed."
    exit 0
fi
