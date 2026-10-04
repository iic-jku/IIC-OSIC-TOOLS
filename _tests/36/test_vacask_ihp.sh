#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test the VACASK model conversion of both IHP PDKs.
#
# install_ihp.sh and install_ihp_cmos5l.sh convert the PDKs' ngspice models for
# VACASK with upstream's converters, which name the files they convert and patch
# in hardcoded tables, while the PDKs are installed unpinned. A corner section
# that includes a file the converter skipped, or a model file it mistranslates,
# only fails once a deck loads that very section. Several shipped that way:
# dio_tt_stat of ihp-sg13g2 ("File not found." on
# sg13g2_dschottky_nbl1_stat.lib), every mos_*_mismatch section of
# cornerMOShv.lib in both PDKs (a syntax error on "stuac=1 40=1"), and every
# cornerMOSCAP.lib section of ihp-sg13cmos5l ("Parameter redefinition." of
# swsoa), while ihp-sg13g2 had no MOSCAP in VACASK at all.
# So this loads every section of every converted corner file of both PDKs and
# the include set of the xschem "Add VACASK models symbol" menu entry, then
# checks two devices against ngspice: the Schottky diode of ihp-sg13g2 in
# dio_tt and dio_tt_stat, and the n-type MOS capacitor of both PDKs.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/36

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Succeeds if $1 is within 0.1 % of the (positive) reference $2.
within() {
    awk -v got="$1" -v ref="$2" \
        'BEGIN {exit !(got != "" && ref > 0 && (got - ref) / ref < 1e-3 && (ref - got) / ref < 1e-3)}'
}

# Compares the VACASK result (a line "RESULT <value>" from the deck's
# postprocessing) with the ngspice one (a line "result = <value>").
compare() {
    local what=$1 spice=$2 sim=$3 ref got
    ref=$(ngspice -b "$spice" 2>/dev/null | awk '/^result = / {print $3}')
    got=$(vacask --extra-tomlfile "$VACASKRC" "$sim" 2>&1 | awk '/^RESULT / {print $2}')
    if within "$got" "$ref"; then
        [ "$DEBUG" = 1 ] && echo "[INFO] $pdk $what: VACASK $got, ngspice $ref"
    else
        echo "[ERROR] $pdk $what: VACASK '$got', ngspice '$ref'"
        ERROR=1
    fi
}

for pdk in ihp-sg13g2 ihp-sg13cmos5l; do
    # shellcheck source=/dev/null
    source sak-pdk-script.sh "$pdk" > /dev/null
    VACASKRC="$PDKPATH/libs.tech/vacask/.vacaskrc.toml"
    MODELS="$PDKPATH/libs.tech/vacask/models"
    COMMON=("$MODELS"/*_vacask_common.lib)
    COMMON=$(basename "${COMMON[0]}")

    # 1. Every section of every corner file loads.
    SECTIONS=0
    for corner in "$MODELS"/corner*.lib; do
        [ -f "$corner" ] || continue
        for section in $(sed -n 's/^section[[:space:]]\+\([^[:space:]]\+\).*/\1/p' "$corner"); do
            SECTIONS=$((SECTIONS + 1))
            cat > section.sim << EOF
$(basename "$corner") section $section

include "$COMMON"
include "$(basename "$corner")" section=$section

model v vsource
v1 (a 0) v dc=1

control
  analysis op1 op
endc
EOF
            if ! vacask --no-output --extra-tomlfile "$VACASKRC" section.sim > section.log 2>&1; then
                echo "[ERROR] $pdk: $(basename "$corner") section $section does not load in VACASK:"
                grep -A3 -E "error|not found|redefinition" section.log | head -6
                ERROR=1
            fi
        done
    done
    if [ "$SECTIONS" -eq 0 ]; then
        echo "[ERROR] $pdk: no corner sections found in $MODELS"
        ERROR=1
    elif [ "$DEBUG" = 1 ]; then
        echo "[INFO] $pdk: $SECTIONS corner sections checked."
    fi

    # 2. The include set the xschem "Add VACASK models symbol" menu entry places
    # loads as a whole, and lists the corners the image adds to it.
    awk '/^name=Libs_VACASK/ {f = 1} f && /^value="$/ {v = 1; next} v && /^"$/ {exit} v {print}' \
        "$PDKPATH/libs.tech/xschem/xschem-vacask" | sed 's/\\"/"/g' > menu.inc
    for corner in cornerDIO.lib cornerMOSCAP.lib; do
        if ! grep -q "\"$corner\"" menu.inc; then
            echo "[ERROR] $pdk: $corner is missing from the xschem VACASK menu."
            ERROR=1
        fi
    done
    cat > menu.sim << EOF
xschem VACASK models symbol

$(cat menu.inc)

model v vsource
v1 (a 0) v dc=1

control
  analysis op1 op
endc
EOF
    if ! vacask --no-output --extra-tomlfile "$VACASKRC" menu.sim > menu.log 2>&1; then
        echo "[ERROR] $pdk: the xschem VACASK models symbol does not load in VACASK:"
        grep -A3 -E "error|not found|redefinition" menu.log | head -6
        ERROR=1
    fi

    # 3. The n-type MOS capacitor has the same capacitance in VACASK and ngspice.
    cat > moscap.spice << EOF
* sg13_moscap_n capacitance
.lib cornerMOSCAP.lib moscap_tt
v1 g 0 dc 1 ac 1
x1 g 0 sg13_moscap_n w=1e-5 l=1e-5
.control
ac lin 1 1e6 1e6
let result = -imag(i(v1)) / (2 * pi * 1e6)
print result
.endc
.end
EOF
    cat > moscap.sim << EOF
sg13_moscap_n capacitance

include "$COMMON"
include "cornerMOSCAP.lib" section=moscap_tt

model v vsource
v1 (g 0) v dc=1 mag=1
x1 (g 0) sg13_moscap_n w=1e-5 l=1e-5

control
  analysis ac1 ac from=1e6 to=1e6 mode="lin" points=1
  postprocess(PYTHON, "check.py")
endc

embed "check.py" <<<FILE
import numpy as np
from rawfile import rawread
plot = rawread("ac1.raw").get()
y = -plot["v1:flow(br)"][0]
print("RESULT %.6e" % (np.imag(y) / (2 * np.pi * np.abs(plot["frequency"][0]))))
>>>FILE
EOF
    compare "sg13_moscap_n capacitance in F" moscap.spice moscap.sim

    # 4. The Schottky diode conducts the same forward current in VACASK and
    # ngspice. VACASK evaluates gauss() at its nominal value outside a Monte
    # Carlo run, so dio_tt_stat has to match dio_tt as well. SG13G2 only, CMOS5L
    # has no Schottky diode.
    [ "$pdk" = ihp-sg13g2 ] || continue
    cat > schottky.spice << EOF
* schottky_nbl1 forward current
.lib cornerDIO.lib dio_tt
v1 a 0 0.3
x1 a 0 0 schottky_nbl1 l=1e-6 w=3e-7
.control
op
let result = -i(v1)
print result
.endc
.end
EOF
    for section in dio_tt dio_tt_stat; do
        cat > schottky.sim << EOF
schottky_nbl1 forward current, section $section

include "$COMMON"
include "cornerDIO.lib" section=$section

model v vsource
v1 (a 0) v dc=0.3
x1 (a 0 0) schottky_nbl1 l=1e-6 w=3e-7

control
  analysis op1 op
  postprocess(PYTHON, "check.py")
endc

embed "check.py" <<<FILE
from rawfile import rawread
print("RESULT %.6e" % -rawread("op1.raw").get()["v1:flow(br)"][0])
>>>FILE
EOF
        compare "schottky_nbl1 current in A ($section)" schottky.spice schottky.sim
    done
done

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <VACASK model conversion of the IHP PDKs> FAILED."
    exit 1
else
    echo "[INFO] Test <VACASK model conversion of the IHP PDKs> passed."
fi

# Cleanup
rm -f -- "$WORKDIR"/*.raw "$WORKDIR"/*.py
exit 0
