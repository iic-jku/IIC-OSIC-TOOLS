#!/usr/bin/env python3
# ========================================================================
# Summary of a LibreLane run (timing, checks, area, step run times, views)
#
# SPDX-FileCopyrightText: 2026 Harald Pretl and Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sak-run-summary.py [--json] [--max <n>] <run dir | design dir>
# ========================================================================

"""Summarize a LibreLane run directory.

The argument is a run directory (``runs/RUN_<date>``) or a design directory
with a ``runs/`` folder, in which case the newest run by modification time is
taken. Exit codes: 0 clean, 1 findings (including an unfinished run), 2 the
directory is no LibreLane run or a file of it is unreadable, 3 wrong usage.

Layout of a run directory, captured from a LibreLane flow of the image
(test 18, IHP sg13g2, 76 steps)::

    runs/RUN_2026-11-22_13-28-54/
      01-verilator-lint/ ... 76-misc-reportmanufacturability/   one folder per step
        runtime.txt        run time of the step as HH:MM:SS.mmm
        state_in.json      state before the step: view name -> file, plus "metrics"
        state_out.json     state after the step, same keys. "metrics" holds ALL
                           metrics collected so far, so the last step that wrote
                           a state_out.json holds the numbers of an unfinished run
        config.json        the resolved configuration of the step
      resolved.json, flow.log, warning.log, error.log, tmp/
      final/               written only after the last step
        metrics.json       flat dict of all metrics (the numbers of a finished run)
        metrics.csv
        <view>/<file>      def, gds, json_h, klayout_gds, lef, mag, mag_gds, nl,
                           odb, pnl, render, sdc, spice, vh
        <view>/<corner>/<file>   lib, sdf (per timing corner), spef (per RC corner)

A step that has not finished has no state_out.json (and possibly no runtime.txt).

Metric names, confirmed against the final/metrics.json of that run. A metric
with a ``__corner:<name>`` suffix exists per timing corner, the name without
suffix is the worst case over the corners. A metric a run does not hold is
null in the result (for example ``magic__drc_error__count`` when Magic DRC
did not run). A check or violation metric that is present but not a finite
number, and a finished run without any check or timing metric, are input
errors: the run cannot be read as clean.
"""

import glob
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # noqa: E402

TOOL = "sak-run-summary"

# result field -> metric name in metrics.json
METRIC_KEYS = {
    "setup_ws_ns": "timing__setup__ws",
    "hold_ws_ns": "timing__hold__ws",
    "setup_violations": "timing__setup_vio__count",
    "hold_violations": "timing__hold_vio__count",
    "drc_klayout": "klayout__drc_error__count",
    "drc_magic": "magic__drc_error__count",
    "lvs_errors": "design__lvs_error__count",
    "antenna_nets": "antenna__violating__nets",
    "route_drc": "route__drc_errors",
    "die_um2": "design__die__area",
    "core_um2": "design__core__area",
    "utilization": "design__instance__utilization",
    "instances": "design__instance__count",
}
CORNER_SETUP_WS = "timing__setup__ws__corner:"
CORNER_HOLD_WS = "timing__hold__ws__corner:"
CORNER_SETUP_VIO = "timing__setup_vio__count__corner:"
CORNER_HOLD_VIO = "timing__hold_vio__count__corner:"
CHECK_FIELDS = ("drc_klayout", "drc_magic", "lvs_errors", "antenna_nets", "route_drc")
TIMING_FIELDS = ("setup_ws_ns", "hold_ws_ns", "setup_violations", "hold_violations")

STEP_RE = re.compile(r"^(\d+)-[A-Za-z0-9_.-]+$")
RUNTIME_RE = re.compile(r"^(\d+):(\d+):(\d+(?:\.\d+)?)$")


def read_json(path: str):
    """The parsed JSON file, InputError if it is missing, truncated or not a JSON object."""
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        raise sak_json.InputError(f"cannot read {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise sak_json.InputError(f"{path} is not a JSON object")
    return data


def step_dirs(run_dir: str) -> list:
    """Names of the step folders of a run, in flow order."""
    try:
        names = [n for n in os.listdir(run_dir) if STEP_RE.match(n) and os.path.isdir(os.path.join(run_dir, n))]
    except OSError:
        return []
    return sorted(names, key=lambda n: (int(STEP_RE.match(n).group(1)), n))


def is_run_dir(path: str) -> bool:
    """A directory with step folders is a LibreLane run."""
    return os.path.isdir(path) and bool(step_dirs(path))


def find_run(path: str) -> str:
    """The run directory for ``path`` (itself, or the newest run below ``path/runs``)."""
    if not os.path.isdir(path):
        raise sak_json.InputError(f"{path} is not a directory")
    if is_run_dir(path):
        return path
    runs = [d for d in glob.glob(os.path.join(path, "runs", "*")) if is_run_dir(d)]
    if not runs:
        raise sak_json.InputError(f"{path} is no LibreLane run directory and has no runs/ folder with a run")
    return max(runs, key=lambda d: (os.stat(d).st_mtime, d))


def runtime_seconds(path: str):
    """Run time of a step in seconds from its runtime.txt, None if missing or malformed."""
    try:
        with open(path, encoding="utf-8") as handle:
            match = RUNTIME_RE.match(handle.read().strip())
    except OSError:
        return None
    if not match:
        return None
    hours, minutes, seconds = match.groups()
    return round(int(hours) * 3600 + int(minutes) * 60 + float(seconds), 3)


def number(value):
    """``value`` if it is a finite number, else None."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        return None
    return value


def count(metrics: dict, key: str):
    """A check or violation metric: None if absent, InputError if present but not a finite number."""
    if key not in metrics:
        return None
    value = number(metrics[key])
    if value is None:
        raise sak_json.InputError(f"metric {key} is {metrics[key]!r}, not a finite number")
    return value


def pick_metrics(run_dir: str, steps: list, finished: bool) -> tuple:
    """(metrics, input file): final/metrics.json, else the state_out.json of the last step that wrote one."""
    if finished:
        path = os.path.join(run_dir, "final", "metrics.json")
        return read_json(path), path
    for name in reversed(steps):
        path = os.path.join(run_dir, name, "state_out.json")
        if os.path.isfile(path):
            metrics = read_json(path).get("metrics")
            if not isinstance(metrics, dict):
                raise sak_json.InputError(f"{path} has no metrics")
            return metrics, path
    return {}, None


def per_corner(metrics: dict, prefix: str, read=None) -> dict:
    """Values of the metrics named ``prefix<corner>``, by corner name, read with ``read`` (default: ``number``)."""
    return {key[len(prefix):]: (read(metrics, key) if read else number(value))
            for key, value in metrics.items() if key.startswith(prefix)}


def worst(metrics: dict, field: str, prefix: str, combine, read=None) -> tuple:
    """(value, corner values): the metric of ``field``, else ``combine`` over the corners (before the corner merge)."""
    corners = per_corner(metrics, prefix, read)
    key = METRIC_KEYS[field]
    value = read(metrics, key) if read else number(metrics.get(key))
    if value is None:
        values = [v for v in corners.values() if v is not None]
        value = combine(values) if values else None
    return value, corners


def timing_facts(metrics: dict) -> dict:
    """Worst slack, violation counts, and slack and violation counts per corner."""
    setup_ws, setup = worst(metrics, "setup_ws_ns", CORNER_SETUP_WS, min)
    hold_ws, hold = worst(metrics, "hold_ws_ns", CORNER_HOLD_WS, min)
    setup_vio, setup_vios = worst(metrics, "setup_violations", CORNER_SETUP_VIO, sum, count)
    hold_vio, hold_vios = worst(metrics, "hold_violations", CORNER_HOLD_VIO, sum, count)
    names = sorted(set(setup) | set(hold) | set(setup_vios) | set(hold_vios))
    corners = [{"corner": name, "setup_ws_ns": setup.get(name), "hold_ws_ns": hold.get(name),
                "setup_violations": setup_vios.get(name), "hold_violations": hold_vios.get(name)}
               for name in names]
    return {"setup_ws_ns": setup_ws, "hold_ws_ns": hold_ws, "setup_violations": setup_vio,
            "hold_violations": hold_vio, "corners": corners}


def final_views(run_dir: str):
    """View name -> file in final/ (view with corner folders: corner -> file), None without final/."""
    final = os.path.join(run_dir, "final")
    if not os.path.isdir(final):
        return None
    views = {}
    for view in sorted(os.listdir(final)):
        folder = os.path.join(final, view)
        if not os.path.isdir(folder):
            continue
        entries = sorted(os.listdir(folder))
        files = [e for e in entries if os.path.isfile(os.path.join(folder, e))]
        subdirs = [e for e in entries if os.path.isdir(os.path.join(folder, e))]
        if subdirs:
            views[view] = {}
            for sub in subdirs:
                inner = sorted(os.listdir(os.path.join(folder, sub)))
                if inner:
                    views[view][sub] = os.path.join(folder, sub, inner[0])
        elif len(files) == 1:
            views[view] = os.path.join(folder, files[0])
        elif files:
            views[view] = [os.path.join(folder, f) for f in files]
    return views


def summarize(run_dir: str, limit: int) -> tuple:
    """(body, inputs) for a run directory."""
    steps = step_dirs(run_dir)
    finished = os.path.isfile(os.path.join(run_dir, "final", "metrics.json"))
    metrics, metrics_path = pick_metrics(run_dir, steps, finished)
    if finished and not any(METRIC_KEYS[field] in metrics for field in CHECK_FIELDS + TIMING_FIELDS):
        raise sak_json.InputError(f"{metrics_path} holds none of the check and timing metrics "
                                  f"({', '.join(METRIC_KEYS[f] for f in CHECK_FIELDS + TIMING_FIELDS)}), "
                                  "this LibreLane version is not supported")
    try:
        timing = timing_facts(metrics)
        checks = {field: count(metrics, METRIC_KEYS[field]) for field in CHECK_FIELDS}
    except sak_json.InputError as exc:
        raise sak_json.InputError(f"{metrics_path}: {exc}") from exc

    def metric(field):
        return number(metrics.get(METRIC_KEYS[field]))

    area = {field: metric(field) for field in ("die_um2", "core_um2", "utilization")}
    step_list = [{"step": name, "runtime_s": runtime_seconds(os.path.join(run_dir, name, "runtime.txt"))}
                 for name in steps]

    findings = []
    if not finished:
        findings.append("run not finished (no final/metrics.json)")
    findings += [f"{field} is {value}" for field, value in checks.items() if value not in (None, 0)]
    findings += [f"{field} is {timing[field]}" for field in ("setup_violations", "hold_violations")
                 if timing[field] not in (None, 0) and timing[field] > 0]

    body = {"run_dir": run_dir, "finished": finished, "last_step": steps[-1], "timing": timing, "checks": checks,
            "area": area, "instances": metric("instances"), "steps": sak_json.cap(step_list, limit),
            "steps_total": len(step_list), "cap": limit, "final_views": final_views(run_dir),
            "findings": findings}
    inputs = [sak_json.input_entry(metrics_path)] if metrics_path else [sak_json.input_entry(run_dir)]
    return body, inputs


def show(value) -> str:
    """A value for the text table, '-' for null."""
    return "-" if value is None else str(value)


def text_summary(body: dict, status: str) -> str:
    """Short text for a person."""
    timing = body["timing"]
    lines = [f"Run {body['run_dir']}: {'finished' if body['finished'] else 'NOT finished'}, "
             f"last step {body['last_step']}, {status}",
             f"Timing (ns): setup ws {show(timing['setup_ws_ns'])}, hold ws {show(timing['hold_ws_ns'])}, "
             f"violations setup {show(timing['setup_violations'])} / hold {show(timing['hold_violations'])}"]
    for corner in timing["corners"]:
        lines.append(f"  {corner['corner']}: setup {show(corner['setup_ws_ns'])} ({show(corner['setup_violations'])} "
                     f"violations), hold {show(corner['hold_ws_ns'])} ({show(corner['hold_violations'])} violations)")
    lines.append("Checks: " + ", ".join(f"{name} {show(value)}" for name, value in body["checks"].items()))
    area = body["area"]
    lines.append(f"Area (um2): die {show(area['die_um2'])}, core {show(area['core_um2'])}, "
                 f"utilization {show(area['utilization'])}, instances {show(body['instances'])}")
    steps = body["steps"]
    slowest = sorted((s for s in steps if s["runtime_s"] is not None), key=lambda s: -s["runtime_s"])[:5]
    lines.append(f"Steps: {body['steps_total']}, slowest of the listed: "
                 + ", ".join(f"{s['step']} {s['runtime_s']} s" for s in slowest))
    views = body["final_views"]
    lines.append("Final views: " + (", ".join(views) if views else "-"))
    lines += [f"Finding: {finding}" for finding in body["findings"]]
    return "\n".join(lines)


def main() -> None:
    """Summarize the run and exit 0 (clean) or 1 (findings)."""
    parser = sak_json.SakArgumentParser(tool=TOOL, description="Summarize a LibreLane run directory.")
    parser.add_argument("path", help="run directory (runs/RUN_...) or design directory with a runs/ folder")
    args = parser.parse_args()
    as_json = args.json

    try:
        run_dir = find_run(args.path)
        body, inputs = summarize(run_dir, args.max)
    except sak_json.InputError as exc:
        sak_json.fail(TOOL, str(exc), as_json)
    status = "clean" if not body["findings"] else "findings"
    sak_json.emit(TOOL, status, inputs, body, as_json, text_summary(body, status))
    sys.exit(sak_json.EXIT_OK if status == "clean" else sak_json.EXIT_FINDINGS)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
