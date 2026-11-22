#!/usr/bin/env python3
# ========================================================================
# Start a long command detached, ask for its status, wait for it, read its log, cancel it
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
# Usage: sak-job.py [-w <workdir>] [--json] [--max <n>] start [-n <name>] -- <command> [args...]
#        sak-job.py [-w <workdir>] [--json] status <id>
#        sak-job.py [-w <workdir>] [--json] wait <id> [--timeout <s>]
#        sak-job.py [-w <workdir>] [--json] tail <id> [-n <lines>]
#        sak-job.py [-w <workdir>] [--json] cancel <id>
#        sak-job.py [-w <workdir>] [--json] list
# ========================================================================

"""Run long commands detached from the calling shell and keep their state in a folder.

``start`` launches a supervisor (this script with an internal subcommand) in a
new session, so the job outlives the starting shell and a ``docker exec``. State
lives in ``<workdir>/.sak-jobs/<id>/``: ``cmd.json`` (argv and the caller's cwd, where the command runs), ``pid`` (of
the supervisor, which is also the process group ID), ``log`` (stdout and stderr
of the command), ``lock`` (held by the supervisor for its whole life), ``start``
(epoch seconds) and, once the job has ended, ``rc``. The process table is never
searched: ``rc`` and the lock decide the state.

States: ``running``, ``done`` (rc 0), ``failed`` (rc not 0), ``cancelled`` and
``lost`` (no ``rc`` and no supervisor holding the lock). The ``status`` field
of the JSON object is ``ok`` for ``done``, ``running`` for ``running``,
``failed`` for ``failed`` and ``cancelled``, and ``error`` for ``lost`` and an
unknown ID, while ``state`` keeps the precise state.

Exit codes: 0 for ``done`` and for a ``start``, ``tail``, ``list`` or ``cancel``
that worked. 1 for ``failed`` and ``cancelled``. 2 for an unknown ID and for
``lost``. 3 for usage. 4 for ``running``, from ``status`` and from a ``wait``
whose timeout passed, so that ``sak-job.py wait <id> && next-step`` never goes on
at a timeout. Code 4 exists only in this script.
"""

import argparse
import collections
import datetime
import fcntl
import json
import os
import random
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import sak_json  # noqa: E402

TOOL = "sak-job"
EXIT_RUNNING = 4
JOBS_DIR = ".sak-jobs"
SUPERVISE = "_supervise"
CANCELLED = "cancelled"
TAIL_DEFAULT = 40
TAIL_RESULT = 10
START_TIMEOUT_S = 10
KILL_GRACE_S = 5


def now_iso(stamp: float) -> str:
    """ISO 8601 UTC with milliseconds."""
    when = datetime.datetime.fromtimestamp(stamp, datetime.timezone.utc)
    return when.strftime("%Y-%m-%dT%H:%M:%S.") + f"{when.microsecond // 1000:03d}Z"


def write_atomic(path: str, text: str) -> None:
    """Write ``text`` to a temporary file and rename it, so a reader never sees half of it."""
    tmp = f"{path}.{os.getpid()}.tmp"  # unique per writer, two cancels may write rc at once
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def read_text(path: str) -> str | None:
    """Content of a small file, None if it does not exist."""
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return None


def supervise(jobdir: str) -> None:
    """Hold the lock, run the command with its output in ``log`` and write ``rc`` at the end."""
    lock = os.open(os.path.join(jobdir, "lock"), os.O_CREAT | os.O_RDWR, 0o644)
    fcntl.flock(lock, fcntl.LOCK_EX)
    cancel_requested = []
    # the command gets the SIGTERM of cancel from the group signal itself, the supervisor stays alive (and keeps the
    # lock) until the command has ended, so a concurrent status never sees a free lock without an rc
    signal.signal(signal.SIGTERM, lambda *_: cancel_requested.append(True))
    with open(os.path.join(jobdir, "cmd.json"), encoding="utf-8") as handle:
        spec = json.load(handle)
    # the supervisor leads its session, so its PID is the process group ID that cancel signals
    write_atomic(os.path.join(jobdir, "pid"), f"{os.getpid()}\n")
    write_atomic(os.path.join(jobdir, "start"), f"{time.time():.3f}\n")
    with open(os.path.join(jobdir, "log"), "ab") as log:
        try:
            proc = subprocess.Popen(spec["argv"], cwd=spec["cwd"], stdin=subprocess.DEVNULL,
                                    stdout=log, stderr=subprocess.STDOUT)
            code = proc.wait()
            if code < 0:
                code = 128 - code
        except OSError as exc:
            log.write(f"[ERROR] cannot run {spec['argv'][0]}: {exc.strerror}\n".encode())
            code = 127 if isinstance(exc, FileNotFoundError) else 126
    write_atomic(os.path.join(jobdir, "rc"), CANCELLED + "\n" if cancel_requested else f"{code}\n")


def lock_is_held(jobdir: str) -> bool:
    """True while a supervisor holds the lock (tried without blocking)."""
    try:
        fd = os.open(os.path.join(jobdir, "lock"), os.O_RDWR)
    except OSError:
        return False
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return True
        return False
    finally:
        os.close(fd)


def log_lines(path: str, count: int) -> list[str]:
    """The last ``count`` lines of a log, streamed so a large log costs no memory."""
    if count <= 0:
        return []
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return [line.rstrip("\n") for line in collections.deque(handle, maxlen=count)]
    except OSError:
        return []


class Job:
    """One job folder."""

    def __init__(self, workdir: str, job_id: str):
        self.id = job_id
        self.dir = os.path.join(workdir, JOBS_DIR, job_id)
        self.log = os.path.join(JOBS_DIR, job_id, "log")

    def exists(self) -> bool:
        return os.path.isdir(self.dir)

    def started(self) -> float | None:
        text = read_text(os.path.join(self.dir, "start"))
        try:
            return float(text) if text else None
        except ValueError:
            return None

    def state(self) -> tuple[str, int | None, float | None]:
        """Return (state, rc, end time). ``rc`` wins, then the lock decides."""
        rc_path = os.path.join(self.dir, "rc")
        text = read_text(rc_path)
        if text is not None:
            try:
                end = os.stat(rc_path).st_mtime
            except OSError:
                end = None
            if text == CANCELLED:
                return "cancelled", None, end
            try:
                code = int(text)
            except ValueError:
                return "failed", None, end
            return ("done" if code == 0 else "failed"), code, end
        if lock_is_held(self.dir):
            return "running", None, None
        # the supervisor was killed by the SIGKILL fallback of cancel, which writes rc a moment later
        if os.path.exists(os.path.join(self.dir, "cancel")):
            return "cancelled", None, None
        return "lost", None, None

    def result(self, with_tail: bool) -> dict:
        state, code, end = self.state()
        begin = self.started()
        elapsed = None
        if begin is not None:
            if end is not None:
                elapsed = max(0.0, end - begin)
            elif state == "running":
                elapsed = max(0.0, time.time() - begin)
        body = {"id": self.id, "state": state, "rc": code,
                "start": now_iso(begin) if begin is not None else None,
                "end": now_iso(end) if end is not None else None,
                "elapsed_s": round(elapsed, 3) if elapsed is not None else None,
                "log": self.log}
        if with_tail:
            body["log_tail"] = log_lines(os.path.join(self.dir, "log"), TAIL_RESULT)
        return body


EXIT_OF_STATE = {"done": sak_json.EXIT_OK, "failed": sak_json.EXIT_FINDINGS,
                 "cancelled": sak_json.EXIT_FINDINGS, "lost": sak_json.EXIT_INPUT,
                 "running": EXIT_RUNNING}
STATUS_OF_STATE = {"done": "ok", "running": "running", "failed": "failed", "cancelled": "failed", "lost": "error"}


def emit_job(job: Job, body: dict, as_json: bool, code: int) -> None:
    """Print the result of ``job`` with the status of its state. A lost job is an error object with ``exit_code``."""
    status = STATUS_OF_STATE[body["state"]]
    if status == "error":
        body = {**body, "error": f"job {job.id} is lost: it has no rc and no supervisor holds its lock",
                "exit_code": code}
    sak_json.emit(TOOL, status, [sak_json.input_entry(job.dir)], body, as_json, text_of(body))


def text_of(body: dict) -> str:
    """Short text for a person."""
    parts = [f"{body['id']}: {body['state']}"]
    if body["rc"] is not None:
        parts.append(f"rc {body['rc']}")
    if body["elapsed_s"] is not None:
        parts.append(f"{body['elapsed_s']:.1f} s")
    lines = [", ".join(parts)]
    lines += [f"  {line}" for line in body.get("log_tail", [])]
    return "\n".join(lines)


def report(job: Job, as_json: bool) -> None:
    """Print the state of ``job`` and exit with the code of that state."""
    body = job.result(True)
    code = EXIT_OF_STATE[body["state"]]
    emit_job(job, body, as_json, code)
    sys.exit(code)


def find_job(args) -> Job:
    job = Job(args.workdir, args.id)
    if not job.exists():
        sak_json.fail(TOOL, f"unknown job {args.id} in {os.path.join(args.workdir, JOBS_DIR)}",
                      args.json, sak_json.EXIT_INPUT)
    return job


def new_id(workdir: str, name: str) -> str:
    """``<name>-<YYYYmmdd-HHMMSS>-<4 hex digits>`` of a folder that does not exist yet."""
    while True:
        stamp = time.strftime("%Y%m%d-%H%M%S")
        job_id = f"{name}-{stamp}-{random.randrange(16 ** 4):04x}"
        try:
            os.makedirs(os.path.join(workdir, JOBS_DIR, job_id))
        except FileExistsError:
            continue
        return job_id


def cmd_start(args) -> None:
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        sak_json.fail(TOOL, "start needs a command after --", args.json, sak_json.EXIT_USAGE)
    if "/" in args.name or args.name.startswith("."):
        sak_json.fail(TOOL, f"invalid job name {args.name}", args.json, sak_json.EXIT_USAGE)
    os.makedirs(os.path.join(args.workdir, JOBS_DIR), exist_ok=True)
    job = Job(args.workdir, new_id(args.workdir, args.name))
    write_atomic(os.path.join(job.dir, "cmd.json"),
                 json.dumps({"argv": command, "cwd": os.getcwd()}) + "\n")
    subprocess.Popen([sys.executable, os.path.realpath(__file__), SUPERVISE, job.dir],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True, close_fds=True)
    # the supervisor writes start once it holds the lock, so a status right after this is never "lost"
    deadline = time.time() + START_TIMEOUT_S
    while job.started() is None:
        if time.time() > deadline:
            sak_json.fail(TOOL, f"supervisor of {job.id} did not start", args.json, sak_json.EXIT_INPUT)
        time.sleep(0.02)
    body = job.result(True)
    sak_json.emit(TOOL, "running", [sak_json.input_entry(job.dir)], body, args.json, job.id)
    sys.exit(sak_json.EXIT_OK)


def cmd_status(args) -> None:
    report(find_job(args), args.json)


def cmd_wait(args) -> None:
    job = find_job(args)
    deadline = None if args.timeout is None else time.time() + args.timeout
    while job.state()[0] == "running":
        if deadline is not None and time.time() >= deadline:
            break
        time.sleep(0.5)
    report(job, args.json)


def cmd_tail(args) -> None:
    job = find_job(args)
    lines = log_lines(os.path.join(job.dir, "log"), args.lines)
    sak_json.emit(TOOL, "ok", [sak_json.input_entry(job.dir)], {"id": job.id, "lines": lines},
                  args.json, "\n".join(lines))
    sys.exit(sak_json.EXIT_OK)


def group_alive(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def wait_group_gone(pgid: int, seconds: float) -> bool:
    deadline = time.time() + seconds
    while group_alive(pgid):
        if time.time() >= deadline:
            return False
        time.sleep(0.1)
    return True


def cmd_cancel(args) -> None:
    job = find_job(args)
    if job.state()[0] == "running":
        try:
            pgid = int(read_text(os.path.join(job.dir, "pid")) or "")
        except ValueError:
            sak_json.fail(TOOL, f"{job.id} has no readable pid file", args.json, sak_json.EXIT_INPUT)
        write_atomic(os.path.join(job.dir, "cancel"), "\n")
        # SIGTERM to the whole group (supervisor and command with its children), SIGKILL after a grace time
        try:
            os.killpg(pgid, signal.SIGTERM)
            if not wait_group_gone(pgid, KILL_GRACE_S):
                os.killpg(pgid, signal.SIGKILL)
                wait_group_gone(pgid, KILL_GRACE_S)
        except ProcessLookupError:
            pass
        deadline = time.time() + KILL_GRACE_S
        while lock_is_held(job.dir) and time.time() < deadline:
            time.sleep(0.05)
        # the supervisor may have finished on its own just before the signal, its rc then stands
        if read_text(os.path.join(job.dir, "rc")) is None:
            write_atomic(os.path.join(job.dir, "rc"), CANCELLED + "\n")
    body = job.result(True)
    # a cancel that worked exits 0, a job that was lost or had failed before keeps its own code
    code = sak_json.EXIT_OK if body["state"] in ("cancelled", "done") else EXIT_OF_STATE[body["state"]]
    emit_job(job, body, args.json, code)
    sys.exit(code)


def cmd_list(args) -> None:
    root = os.path.join(args.workdir, JOBS_DIR)
    try:
        ids = [name for name in os.listdir(root) if os.path.isdir(os.path.join(root, name))]
    except OSError:
        ids = []
    jobs = [Job(args.workdir, name) for name in ids]
    jobs.sort(key=lambda job: (job.started() or 0.0, job.id))
    shown = [job.result(False) for job in sak_json.cap(jobs, args.max)]
    body = {"jobs": shown, "total": len(jobs), "cap": args.max}
    text = "\n".join(text_of(item) for item in shown) or "no jobs"
    sak_json.emit(TOOL, "ok", [], body, args.json, text)
    sys.exit(sak_json.EXIT_OK)


class SubParser(sak_json.SakArgumentParser):
    """Subcommand parser: ``--json`` and ``--max`` may follow the subcommand without resetting the values given before it."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, tool=TOOL, **kwargs)
        for action in self._actions:
            if action.dest in ("json", "max"):
                action.default = argparse.SUPPRESS


def build_parser() -> argparse.ArgumentParser:
    parser = sak_json.SakArgumentParser(tool=TOOL, description="Run long commands detached and follow them.")
    parser.add_argument("-w", "--workdir", default=".", help="folder holding .sak-jobs (default: current directory)")
    sub = parser.add_subparsers(dest="action", required=True, parser_class=SubParser, metavar="command")
    start = sub.add_parser("start", help="start a command detached and print the job ID")
    start.add_argument("-n", "--name", default="job", help="name part of the ID (default: job)")
    start.add_argument("command", nargs=argparse.REMAINDER, help="-- <command> [args...]")
    start.set_defaults(func=cmd_start)
    for name, func, text in (("status", cmd_status, "state of a job"),
                             ("wait", cmd_wait, "wait until a job has ended"),
                             ("tail", cmd_tail, "last lines of the log"),
                             ("cancel", cmd_cancel, "stop a job and its child processes")):
        item = sub.add_parser(name, help=text)
        item.add_argument("id", help="job ID")
        item.set_defaults(func=func)
        if name == "wait":
            item.add_argument("--timeout", type=float, default=None, metavar="S",
                              help="give up after S seconds (exit code 4)")
        if name == "tail":
            item.add_argument("-n", "--lines", type=int, default=TAIL_DEFAULT, metavar="N",
                              help=f"number of lines (default: {TAIL_DEFAULT})")
    listing = sub.add_parser("list", help="all jobs of the folder")
    listing.set_defaults(func=cmd_list)
    return parser


def main() -> None:
    # internal entry of the detached supervisor, not part of the usage text
    if len(sys.argv) == 3 and sys.argv[1] == SUPERVISE:
        supervise(sys.argv[2])
        return
    args = build_parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    sak_json.run(TOOL, main)
