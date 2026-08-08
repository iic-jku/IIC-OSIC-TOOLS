#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test the cap_cmomi MoM capacitor of ihp-sg13cmos5l in ngspice and VACASK.
#
# cap_cmomi is the PDK's only capacitor and its only own Verilog-A model, so it
# is the one device that exercises the CMOS5L-specific parts of the image:
# the OSDI object built by install_ihp_cmos5l.sh, the PDK .spiceinit picked up
# via SPICE_USERINIT_DIR, and the ng2vclib model conversion for VACASK.
#
# The reference capacitances are the values the KLayout PCell writes into its
# own C= label, so a drift makes layout and simulation disagree.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR=${RUNS_DIR}/${RAND}/29

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# Switch to the cmos5l PDK (also points SPICE_USERINIT_DIR at its .spiceinit,
# which is what loads cap_cmomi.osdi)
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13cmos5l > /dev/null

ngspice --output="$WORKDIR"/ngspice.log -b "$DIR"/cap_cmomi.spice > /dev/null 2>&1 || ERROR=1
# The PDK ships its VACASK search paths as a sample .vacaskrc.toml that a user
# copies into the design directory; load it explicitly instead.
vacask --extra-tomlfile "$PDKPATH/libs.tech/vacask/.vacaskrc.toml" \
       "$DIR"/cap_cmomi.sim > "$WORKDIR"/vacask.log 2>&1 || ERROR=1

# Both decks report one PASS/FAIL line per configuration; a missing line means
# the simulation never got that far, so count the passes instead of only
# grepping for FAIL.
PASSES=$(grep -c "PASS cap_cmomi" "$WORKDIR"/ngspice.log "$WORKDIR"/vacask.log 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
if [ "$PASSES" -ne 4 ]; then
    echo "[ERROR] expected 4 passing cap_cmomi checks, got $PASSES"
    grep -h "cap_cmomi\|Parameter .* not found" "$WORKDIR"/ngspice.log "$WORKDIR"/vacask.log 2>/dev/null
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <cap_cmomi with ihp-sg13cmos5l> FAILED."
    exit 1
else
    echo "[INFO] Test <cap_cmomi with ihp-sg13cmos5l> passed."
fi

# Cleanup
rm -f -- "$WORKDIR"/*.raw "$WORKDIR"/*.py
exit 0
