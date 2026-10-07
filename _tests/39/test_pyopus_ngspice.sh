#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test PyOPUS: compiled extensions, an ngspice run through the performance
# evaluator and the cost aggregator report, the measure fix of commit
# 3ee2f57 and a plot saved through the plotter ported to PySide6 at install time.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/39
LOG=$WORKDIR/pyopus.log

mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

cat > divider.cir <<'EOF'
* Resistive divider
vin in 0 dc {vsup}
r1 in out {r1}
r2 out 0 {r2}
EOF

cat > pyopus_test.py <<'EOF'
import importlib
import os

import numpy as np

# The plotter needs a Qt platform, none is attached in the test container
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from pyopus.evaluator.aggregate import Aggregator, Nabove, Nbelow, Rworst
from pyopus.evaluator.auxfunc import paramList
from pyopus.evaluator.measure import XatIrange
from pyopus.evaluator.performance import PerformanceEvaluator

for mod in ("pyopus.simulator._rawfile", "pyopus.simulator._hspice_read",
            "pyopus.misc._ghalton", "pyopus.misc._sobol", "pyopus.problems._lvu"):
    importlib.import_module(mod)

# PyOPUS 0.12 raised NameError here (undefined np, fixed upstream in 3ee2f57)
assert np.allclose(XatIrange(np.array([0.0, 1.0, 2.0, 3.0]), 1.5, 1.5), [1.5])

heads = {
    "ng": {
        "simulator": "Ngspice",
        "moddefs": {"def": {"file": "divider.cir"}},
        "params": {"vsup": 1.0},
    }
}
analyses = {
    "op": {"head": "ng", "modules": ["def"], "saves": [], "command": "op()"},
    "dc": {"head": "ng", "modules": ["def"], "saves": [],
           "command": "dc(0.0, 2.0, 'lin', 9, 'vin')"},
}
corners = {"nominal": {"modules": [], "params": {"temperature": 25}}}
measures = {
    "vout": {"analysis": "op", "corners": ["nominal"], "expression": "v('out')"},
    "dcout": {"analysis": "dc", "corners": ["nominal"], "expression": "v('out')",
              "vector": True},
}
definition = [
    {"measure": "vout", "norm": Nabove(0.2, 0.1)},
    {"measure": "dcout", "norm": Nbelow(1.5, 0.1), "reduce": Rworst()},
]
params = {"r1": 3e3, "r2": 1e3}
inOrder = sorted(params)

pe = PerformanceEvaluator(heads, analyses, measures, corners, debug=0)
ce = Aggregator(pe, definition, inOrder, debug=0)
try:
    cf = ce(paramList(params, inOrder))
    vout = pe.results["vout"]["nominal"]
    dcout = pe.results["dcout"]["nominal"]
    assert vout is not None and abs(vout - 0.25) < 1e-6, f"vout={vout}"
    assert dcout is not None and abs(np.max(dcout) - 0.5) < 1e-6, f"dcout={dcout}"
    # Formatting a worst-case vector result failed in 0.12 (fixed upstream in 56e601e)
    print(ce.formatResults())
    print(f"cost={cf:e}")
finally:
    pe.finalize()

# The plotter runs Qt in a thread started at import, every call below crosses
# into it through the PySide6 signal patched in by the install script
from pyopus.plotter import interface as pyopl  # noqa: E402

fig = pyopl.figure(windowTitle="dc", show=False, figpx=(400, 300), dpi=100)
pyopl.lock(True)
if pyopl.alive(fig):
    fig.gca().plot(dcout)
    pyopl.draw(fig)
pyopl.lock(False)
pyopl.saveFigure(fig, "dcout.png")
pyopl.close(fig)
assert os.path.getsize("dcout.png") > 0, "plotter wrote no dcout.png"

# join() ends the process with os._exit(), which skips flushing stdout
print("PYOPUS_TEST_OK", flush=True)
pyopl.shutdown()
pyopl.join()
EOF

python3 pyopus_test.py > "$LOG" 2>&1 || ERROR=1
grep -q PYOPUS_TEST_OK "$LOG" || ERROR=1

if [ -n "${DEBUG}" ]; then
    cat "$LOG"
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <PyOPUS with ngspice> FAILED."
    exit 1
else
    echo "[INFO] Test <PyOPUS with ngspice> passed."
    exit 0
fi
