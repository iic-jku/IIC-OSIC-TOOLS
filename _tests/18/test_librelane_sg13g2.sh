#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test LibreLane for IHP-SG13G2

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

if command -v librelane >/dev/null 2>&1; then
    LOG=${RUNS_DIR}/${RAND}/18/result_ll_sg13g2.log
    STDERR_LOG=${RUNS_DIR}/${RAND}/18/result_ll_sg13g2.stderr.log
    WORKDIR=${RUNS_DIR}/${RAND}/18
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Switch to ihp-sg13g2 PDK
    # shellcheck source=/dev/null
    source sak-pdk-script.sh ihp-sg13g2 sg13g2_stdcell > /dev/null
    # Run the LibreLane smoke test
    mkdir -p "$WORKDIR"
    find "$DIR" -maxdepth 1 -type f -exec cp {} "$WORKDIR" \;
    librelane --manual-pdk "$WORKDIR/counter.json" > "$LOG" 2> "$STDERR_LOG"
    LL_RC=$?

    # Grepping the stdout log for "ERROR" is not enough on its own. A step that
    # dies from an uncaught exception prints its traceback on stderr, leaves no
    # "ERROR" in the stdout log, and the run's own error.log stays empty -- so
    # this test would report "passed" over a flow that crashed in its very last
    # step, which is what happened to test 19 (gzipped Liberty, see
    # install_eda.sh). Check the exit code, both logs, and that the flow
    # actually reached its end.
    FAILED=""
    [ "$LL_RC" -eq 0 ] || FAILED="librelane exited with $LL_RC"
    if [ -z "$FAILED" ] && grep -q "ERROR" "$LOG"; then
        FAILED="ERROR in the stdout log"
    fi
    if [ -z "$FAILED" ] && grep -q "Traceback (most recent call last)" "$STDERR_LOG"; then
        FAILED="Python traceback in the stderr log"
    fi
    # The flow writes final/metrics.json only after its last step, so a missing
    # one means the run stopped early no matter how quiet it was.
    if [ -z "$FAILED" ] && \
        [ -z "$(find "$WORKDIR/runs" -maxdepth 3 -path "*/final/metrics.json" -print -quit 2>/dev/null)" ]; then
        FAILED="the flow produced no final/metrics.json"
    fi

    # sak-run-summary.py reads the run directory the flow just wrote
    if [ -z "$FAILED" ]; then
        SUMMARY_ERR=$(WORKDIR="$WORKDIR" RUNS_DIR="$RUNS_DIR" RAND="$RAND" python3 - <<'PYEOF' 2>&1
import json, os, shutil, subprocess, sys

workdir = os.environ["WORKDIR"]
debug = os.environ.get("DEBUG") == "1"


def summary(path):
    try:
        proc = subprocess.run(["sak-run-summary.py", "--json", path], capture_output=True, text=True, check=False)
    except FileNotFoundError:
        sys.exit("sak-run-summary.py: command not found")
    if debug:
        print(proc.stdout, proc.stderr, file=sys.stderr)
    try:
        return proc.returncode, json.loads(proc.stdout)
    except ValueError:
        sys.exit(f"sak-run-summary.py {path}: no JSON on stdout (exit {proc.returncode}): {proc.stderr.strip()[:300]}")


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


code, design = summary(workdir)
if code not in (0, 1):
    sys.exit(f"design dir: exit {code}")
if design.get("finished") is not True:
    sys.exit("design dir: finished is not true")
if not number(design["timing"]["setup_ws_ns"]):
    sys.exit("design dir: timing.setup_ws_ns is not a number")
if design["checks"]["lvs_errors"] != 0:
    sys.exit(f"design dir: checks.lvs_errors is {design['checks']['lvs_errors']}")
gds = design["final_views"].get("gds")
if not gds or not os.path.isfile(gds):
    sys.exit(f"design dir: final_views.gds {gds!r} is no file")
if len(design["steps"]) <= 10:
    sys.exit(f"design dir: only {len(design['steps'])} steps")
if not all(number(step["runtime_s"]) for step in design["steps"]):
    sys.exit("design dir: a step runtime_s is not a number")

code, direct = summary(design["run_dir"])
if code not in (0, 1) or direct["run_dir"] != design["run_dir"]:
    sys.exit(f"run dir: exit {code}, run_dir {direct.get('run_dir')!r} differs from {design['run_dir']!r}")

copy = os.path.join(os.environ["RUNS_DIR"], os.environ["RAND"], "18_nofinal")
shutil.rmtree(copy, ignore_errors=True)
shutil.copytree(design["run_dir"], copy, symlinks=True)
shutil.rmtree(os.path.join(copy, "final"))
code, partial = summary(copy)
if code != 1 or partial.get("finished") is not False:
    sys.exit(f"run without final/: exit {code}, finished {partial.get('finished')!r}")
if not isinstance(partial.get("last_step"), str) or not partial["last_step"]:
    sys.exit("run without final/: last_step is not a non-empty string")
shutil.rmtree(copy, ignore_errors=True)

empty = os.path.join(os.environ["RUNS_DIR"], os.environ["RAND"], "18_empty")
os.makedirs(empty, exist_ok=True)
code, none = summary(empty)
os.rmdir(empty)
if code != 2 or none.get("status") != "error":
    sys.exit(f"empty dir: exit {code}, status {none.get('status')!r}")
PYEOF
)
        [ $? -eq 0 ] || FAILED="sak-run-summary.py check failed: $SUMMARY_ERR"
    fi

    if [ -n "$FAILED" ]; then
        echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13g2> FAILED ($FAILED). Check the logs <$LOG> and <$STDERR_LOG>."
        exit 1
    else
        echo "[INFO] Test <LibreLane smoke-test with ihp-sg13g2> passed."
        exit 0
    fi
else
    echo "[ERROR] Test <LibreLane smoke-test with ihp-sg13g2> FAILED. LibreLane is not installed!"
    exit 1
fi
