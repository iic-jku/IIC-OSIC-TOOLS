#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that netgen derives the MIM capacitor area of the IHP-SG13G2 setup
# independently of the netlist file paths.
#
# Up to netgen 1.5.331, derivedprops() in base/netcmp.c returned no value, so
# the walk over the cell table that adds the derived "area" property stopped
# at a random cell. The cell table order depends on the cell names, which
# include the netlist file paths, so the same LVS passed in one directory and
# failed in another ("Property area in circuit1 has no matching property in
# circuit2"), and a wrongly sized capacitor could pass. Fixed in netgen
# 287d6eac (RTimothyEdwards/netgen#113), first released in 1.5.332.
# The netlists are compared in a set of directories, since one directory hits
# the bug only for some names.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}
ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/51

mkdir -p "$WORKDIR"

# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null
SETUP="$PDK_ROOT/$PDK/libs.tech/netgen/${PDK}_setup.tcl"

# compare <dir> <schematic l> <expect: match|mismatch>
compare() {
    local dir=$1 len=$2 expect=$3 got=match
    mkdir -p "$dir"
    printf '.subckt cap C1 C0\nX0 C0 C1 cap_cmim l=7u w=7u\n.ends\n' > "$dir/lay.spice"
    printf '.subckt cap C0 C1\nXC1 C0 C1 cap_cmim w=7.0e-6 l=%s m=1\n.ends\n' "$len" > "$dir/sch.spice"
    netgen -batch lvs "$dir/lay.spice cap" "$dir/sch.spice cap" "$SETUP" "$dir/lvs.out" > "$dir/lvs.log" 2>&1
    if ! grep -q "^Final result: Circuits match uniquely\.$" "$dir/lvs.out" \
            || grep -q -e "^Property errors were found\." -e "has no matching property" "$dir/lvs.out"; then
        got=mismatch
    fi
    if [ "$got" != "$expect" ]; then
        echo "[ERROR] netgen reports a $got in <$dir> (schematic l=$len), expected a $expect."
        ERROR=1
    elif [ "$DEBUG" = 1 ]; then
        echo "[INFO] netgen reports a $got in <$dir> (schematic l=$len) as expected."
    fi
}

for i in $(seq -w 1 32); do
    compare "$WORKDIR/d$i/ok" 7.0e-6 match
    compare "$WORKDIR/d$i/wrong" 8.0e-6 mismatch
done

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <netgen derived MIM capacitor area with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <netgen derived MIM capacitor area with ihp-sg13g2> passed."
    exit 0
fi
