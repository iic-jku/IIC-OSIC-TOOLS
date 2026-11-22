#!/usr/bin/env python3
# ========================================================================
# Shared JSON contract of the sak agent helper commands
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
# Imported by the sak-*.py helpers (not a command itself).
# ========================================================================

"""Shared contract of the sak agent helper commands.

Every command prints either short text or, with ``--json``, exactly one JSON
object on stdout (``schema`` 1, ``tool``, ``status``, ``input``, plus a
command specific body). Messages for a person go to stderr. Exit codes:
0 clean or successful, 1 findings, 2 input missing or unreadable, 3 usage.
"""

import argparse
import datetime
import json
import os
import sys
from typing import NoReturn

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_INPUT = 2
EXIT_USAGE = 3

SCHEMA = 1


class InputError(Exception):
    """An input file is missing, unreadable, truncated or stale."""


class SakArgumentParser(argparse.ArgumentParser):
    """ArgumentParser with ``--json``/``--max`` and the usage exit code."""

    def __init__(self, *args, tool: str | None = None, **kwargs):
        super().__init__(*args, **kwargs)
        self.tool = tool or self.prog
        self.add_argument("--json", action="store_true", dest="json",
                          help="print one JSON object instead of text")
        self.add_argument("--max", type=int, default=20, metavar="N",
                          help="list at most N entries, 0 for all (default: 20)")

    def error(self, message: str) -> NoReturn:
        # argparse exits with 2, which is reserved for input errors here
        self.print_usage(sys.stderr)
        if "--json" in sys.argv[1:]:
            fail(self.tool, message, True, EXIT_USAGE)
        print(f"[ERROR] {message}", file=sys.stderr)
        sys.exit(EXIT_USAGE)


def input_entry(path: str) -> dict:
    """Return {"path", "mtime"} of an input file, mtime as ISO 8601 UTC."""
    try:
        mtime = os.stat(path).st_mtime
    except OSError as exc:
        raise InputError(f"cannot read {path}: {exc.strerror}") from exc
    stamp = datetime.datetime.fromtimestamp(mtime, datetime.timezone.utc)
    return {"path": path, "mtime": stamp.strftime("%Y-%m-%dT%H:%M:%SZ")}


def emit(tool: str, status: str, inputs: list, body: dict,
         as_json: bool, text: str) -> None:
    """Print the result object (``--json``) or ``text`` on stdout."""
    if as_json:
        obj = {"schema": SCHEMA, "tool": tool, "status": status,
               "input": inputs, **body}
        print(json.dumps(obj))
    else:
        print(text)


def fail(tool: str, message: str, as_json: bool, code: int = EXIT_INPUT,
         extra: dict | None = None) -> NoReturn:
    """Report an error (JSON object on stdout with ``--json``) and exit."""
    if as_json:
        obj = {"schema": SCHEMA, "tool": tool, "status": "error",
               "error": message, "input": [], **(extra or {})}
        print(json.dumps(obj))
    print(f"[ERROR] {message}", file=sys.stderr)
    sys.exit(code)


def cap(items: list, limit: int) -> list:
    """The first ``limit`` items, all of them for 0."""
    return list(items) if limit == 0 else list(items[:limit])


def run(tool: str, main) -> None:
    """Call ``main()``, turning an unexpected exception into exit code 2.

    Without this a traceback ends with Python's exit code 1, which means
    "findings" in this contract.
    """
    try:
        main()
    except Exception as exc:  # pylint: disable=broad-except
        fail(tool, f"unexpected {type(exc).__name__}: {exc}", "--json" in sys.argv[1:])
