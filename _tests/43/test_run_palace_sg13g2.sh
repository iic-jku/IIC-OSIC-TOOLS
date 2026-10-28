#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that run_palace runs Palace on several MPI processes (-np 2).
#
# run_palace used to wrap Palace's own launcher (palace, which calls mpirun itself) in a second mpirun, so every -np above 1 aborted with "mpirun does not support recursive calls".
# The 500 pH inductor example of the ihp-sg13g2 Palace workflow is meshed with gds2palace and solved at one frequency at element order 1, which takes well under a minute.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DEBUG=${DEBUG:-0}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/43
MODEL=inductor_500pH_2port
DATA=palace_model/${MODEL}_data

mkdir -p "$WORKDIR"

# Switch to sg13g2 PDK
# shellcheck source=/dev/null
source sak-pdk-script.sh ihp-sg13g2 > /dev/null

# libs.tech/palace is the PDK's gds2palace_ihp_sg13g2 submodule. Its example imports the gds2palace copy next to it, and newer revisions read the stackup from ../XML_stackup, so the folder is copied except doc and more_examples, which hold almost all of its size (67 MB of doc in 2026.10, 76 MB of examples in newer revisions).
PALACE_DIR=$PDK_ROOT/$PDK/libs.tech/palace
if [ ! -f "$PALACE_DIR/workflow/$MODEL.py" ]; then
    echo "[ERROR] The Palace example $PALACE_DIR/workflow/$MODEL.py is missing."
    echo "[ERROR] Test <run_palace with two MPI processes> FAILED."
    exit 1
fi
mkdir -p "$WORKDIR/palace"
for ITEM in "$PALACE_DIR"/*; do
    case "$(basename "$ITEM")" in
        doc|more_examples) ;;
        *) cp -r "$ITEM" "$WORKDIR/palace/" || exit 1 ;;
    esac
done
cd "$WORKDIR/palace/workflow" || exit 1

# Without no_gui, gmsh opens a window, which blocks forever without a display.
sed -i "s/^settings={}$/settings={}\nsettings['no_gui'] = True/" "$MODEL.py"
if ! grep -q "^settings\['no_gui'\] = True" "$MODEL.py"; then
    echo "[ERROR] Cannot switch off the gmsh GUI in $MODEL.py, the example has changed."
    echo "[ERROR] Test <run_palace with two MPI processes> FAILED."
    exit 1
fi

if timeout 600 python3 "$MODEL.py" > generate.log 2>&1 && [ -s "$DATA/config.json" ]; then
    # One frequency point at order 1 instead of the example's sweep at order 2.
    python3 - "$DATA/config.json" "$DATA/config_quick.json" << 'EOF'
import json
import sys

config = json.load(open(sys.argv[1]))
config["Solver"]["Order"] = 1
config["Solver"]["Driven"] = {"Samples": [{"Type": "Point", "Freq": [10.0], "SaveStep": 0}], "AdaptiveTol": 0}
json.dump(config, open(sys.argv[2], "w"), indent=1)
EOF
    cd "$DATA" || exit 1
    # mpirun forwards stdin to rank 0, so it gets /dev/null.
    if timeout 600 run_palace -np 2 config_quick.json > palace.log 2>&1 < /dev/null; then
        if ! grep -q "Running with 2 MPI processes" palace.log; then
            echo "[ERROR] Palace did not report 2 MPI processes:"
            grep -m 1 "Running with" palace.log || tail -4 palace.log
            ERROR=1
        fi
        if [ ! -s "output/$MODEL/port-S.csv" ]; then
            echo "[ERROR] Palace wrote no S-parameters (output/$MODEL/port-S.csv)."
            ERROR=1
        elif [ "$DEBUG" = "1" ]; then
            echo "[INFO] Palace ran on 2 MPI processes and wrote output/$MODEL/port-S.csv."
        fi
    else
        echo "[ERROR] run_palace -np 2 failed:"
        grep -m 2 -E "recursive|slots|ERROR|Error" palace.log || tail -4 palace.log
        ERROR=1
    fi
else
    echo "[ERROR] gds2palace cannot generate the $MODEL model:"
    tail -4 generate.log
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <run_palace with two MPI processes> FAILED."
    exit 1
else
    echo "[INFO] Test <run_palace with two MPI processes> passed."
    exit 0
fi
