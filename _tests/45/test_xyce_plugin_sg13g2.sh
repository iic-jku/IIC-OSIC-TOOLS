#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that buildxyceplugin compiles a Verilog-A model into a working Xyce plugin.
#
# Xyce is built with MPI, so its installed headers include <mpi.h>, and
# buildxyceplugin compiles with mpicxx. Since libopenmpi-dev moved to base-dev
# (00316c4f, image 2025.11), every compile in the container stopped at
# "mpi.h: No such file or directory", and with it the IHP PDKs'
# libs.tech/verilog-a/adms-compile-va.sh. The r3_cmc model of ihp-sg13g2 is
# compiled the way that script does it, and the plugin has to reproduce the
# PDK's prebuilt one on the rsil, rppd and rhigh resistors, within 1e-6.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/45

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Switch to sg13g2 PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null
VA_DIR=$PDK_ROOT/ihp-sg13g2/libs.tech/verilog-a/r3_cmc
PREBUILT=$PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_r3_cmc.so

# One deck per run, each printing to its own file.
write_deck() {
    cat > "$1.cir" << EOF
* SG13G2 poly resistors through the r3_cmc model
Vres Vcc 0 1.5
Vsil Vcc net1 0
Vppd Vcc net2 0
Vrh Vcc net3 0
XR1 0 net1 0 rsil w=0.5e-6 l=10e-6 m=1 b=0
XR2 0 net2 0 rppd w=0.5e-6 l=0.5e-6 m=1 b=0
XR3 0 net3 0 rhigh w=0.5e-6 l=0.5e-6 m=1 b=0
.option temp=27
.dc Vres 0 1 0.1
.print dc format=csv file=$WORKDIR/$1.csv I(Vsil) I(Vppd) I(Vrh)
.lib $PDK_ROOT/ihp-sg13g2/libs.tech/xyce/models/cornerRES.lib res_typ
.end
EOF
}

# Same header, same rows, every value within a relative 1e-6. The prebuilt
# plugin is compiled in the open_pdks stage, which can carry another GCC point
# release than this image, so a byte-for-byte compare could fail on the last
# printed digit.
same_results() {
    awk -F, -v tol=1e-6 '
        NR == FNR { ref[FNR] = $0; nref = FNR; next }
        {
            nrow = FNR
            if (split(ref[FNR], r, ",") != NF) { bad = 1; exit }
            for (i = 1; i <= NF; i++) {
                if (FNR == 1) { if ($i != r[i]) { bad = 1; exit } continue }
                a = $i + 0; b = r[i] + 0
                d = (a > b) ? a - b : b - a
                m = (a < 0) ? -a : a
                if (b > m) m = b
                if (-b > m) m = -b
                if (d > tol * m) { bad = 1; exit }
            }
        }
        END { exit (bad || nrow != nref) }' "$1" "$2"
}

# The same call as adms-compile-va.sh, on a copy, since the build writes next
# to the sources.
mkdir -p va plugin
cp "$VA_DIR"/* va/
(cd va && buildxyceplugin r3_cmc.va "$WORKDIR"/plugin > build.log 2>&1)
if [ ! -f plugin/Xyce_Plugin_r3_cmc.so ]; then
    echo "[ERROR] buildxyceplugin cannot compile r3_cmc.va:"
    grep -h -m 4 -E "fatal error|error:" va/buildxyceplugin.log va/build.log 2>/dev/null || tail -4 va/build.log
    ERROR=1
else
    write_deck rebuilt
    write_deck prebuilt
    write_deck noplugin
    RUN_OK=1
    xyce -plugin "$WORKDIR"/plugin/Xyce_Plugin_r3_cmc.so rebuilt.cir > rebuilt.log 2>&1 || RUN_OK=0
    xyce -plugin "$PREBUILT" prebuilt.cir > prebuilt.log 2>&1 || RUN_OK=0
    if [ $RUN_OK -eq 0 ]; then
        echo "[ERROR] Xyce fails on the resistor deck:"
        grep -h -m 4 -i "error" rebuilt.log prebuilt.log
        ERROR=1
    elif xyce noplugin.cir > noplugin.log 2>&1; then
        # Without a plugin the deck must fail, or it does not exercise r3_cmc at all.
        echo "[ERROR] The resistor deck runs without the r3_cmc plugin, so it checks nothing."
        ERROR=1
    elif [ ! -s rebuilt.csv ] || [ ! -s prebuilt.csv ]; then
        echo "[ERROR] Xyce wrote no results to rebuilt.csv or prebuilt.csv."
        ERROR=1
    elif [ "$(grep -c . rebuilt.csv)" -ne 12 ] || [ "$(grep -c . prebuilt.csv)" -ne 12 ]; then
        echo "[ERROR] Xyce prints $(grep -c . rebuilt.csv) lines with the rebuilt and $(grep -c . prebuilt.csv) with the prebuilt plugin, expected 12."
        ERROR=1
    elif ! same_results prebuilt.csv rebuilt.csv; then
        echo "[ERROR] The rebuilt r3_cmc plugin does not reproduce the PDK's prebuilt one:"
        diff prebuilt.csv rebuilt.csv | head -6
        ERROR=1
    elif [ "$DEBUG" = "1" ]; then
        if cmp -s rebuilt.csv prebuilt.csv; then SAME="byte-identical"; else SAME="equal within 1e-6"; fi
        echo "[INFO] Rebuilt and prebuilt r3_cmc plugins are $SAME, at 1 V: $(tail -1 rebuilt.csv)"
    fi
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <Xyce plugin build with ihp-sg13g2> FAILED."
    exit 1
else
    echo "[INFO] Test <Xyce plugin build with ihp-sg13g2> passed."
    exit 0
fi
