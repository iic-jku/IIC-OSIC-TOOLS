#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
"""Make the IHP KLayout PCell library preprocessor temp file per-process.

Both IHP PCell libraries run every PCell module through pypreprocessor into a
file in the system temp dir, import it, and delete it again:

    modulePreProcPath = os.path.join(tempfile.gettempdir(), f"{moduleName}_pre.py")
    ...
    spec.loader.exec_module(module)
    os.remove(modulePreProcPath)

The name carries no process identity, /tmp is shared, and SG13G2 and SG13CMOS5L
use the same module names (rfnmos_code, bondpad_code, ...). Two KLayout
processes loading an IHP technology at the same time therefore write and delete
the *same* file, and the loser dies with

    FileNotFoundError: [Errno 2] No such file or directory: '/tmp/rfnmos_code_pre.py'

Since that exception escapes the PyCellLib() constructor called from autorun.lym,
the whole library fails to register: not one broken PCell, but zero PCells. Two
KLayout windows, or an LVS/DRC job next to an interactive session, are enough to
trigger it.

This patch gives the file a per-process name and makes the removal tolerant of a
file that is already gone. Write, import and remove are strictly sequential
within one process, so the PID is enough to make the name unique even when a
single process loads both PCell libraries.

Each PDK ships its own copy of __init__.py (unlike ihp/utility_functions.py,
pycell4klayout-api and pypreprocessor, which SG13CMOS5L symlinks into SG13G2),
so both installers run this helper on their own file.

The rewrite is idempotent, so re-running it on an already patched file is a
no-op. Reported as https://github.com/IHP-GmbH/IHP-Open-PDK/issues/1087; remove
this once the fix has landed upstream.
"""

import re
import sys

TEMPPATH_OLD = 'os.path.join(tempfile.gettempdir(), f"{moduleName}_pre.py")'
TEMPPATH_NEW = 'os.path.join(tempfile.gettempdir(), f"{moduleName}_{os.getpid()}_pre.py")'

REMOVE_RE = re.compile(r'^([ \t]*)os\.remove\(modulePreProcPath\)[ \t]*$', re.MULTILINE)


def patch(content: str) -> str:
    content = content.replace(TEMPPATH_OLD, TEMPPATH_NEW)
    # Naturally idempotent for the temp path: the patched text no longer
    # contains the searched one. The removal needs an explicit guard, because
    # the os.remove() call survives the rewrite inside the try block.
    if 'except FileNotFoundError' not in content:
        content = REMOVE_RE.sub(
            lambda m: '%stry:\n%s    os.remove(modulePreProcPath)\n'
                      '%sexcept FileNotFoundError:\n%s    pass'
                      % (m.group(1), m.group(1), m.group(1), m.group(1)),
            content,
        )
    return content


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <pycell_lib/__init__.py>", file=sys.stderr)
        return 2
    fname = sys.argv[1]
    with open(fname, 'r') as f:
        content = f.read()
    patched = patch(content)
    if patched == content:
        print(f"[INFO] PCell preprocessor temp file already per-process in {fname}")
        return 0
    with open(fname, 'w') as f:
        f.write(patched)
    print(f"[INFO] Made the PCell preprocessor temp file per-process in {fname}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
