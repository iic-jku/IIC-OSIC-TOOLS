# The image uninstalls PySide6-Addons to save ~340 MB (QtWebEngine, Qt3D, ...).
# The Essentials, Addons and meta-package wheels all ship the same top-level
# PySide6 files (__init__.py, _config.py, _git_pyside_version.py, the .pyi
# stubs), and pip does no cross-package refcounting -- so that uninstall
# happily deletes files the remaining packages still own. Check that every
# file the installed PySide6 distributions claim is actually on disk, which
# catches the whole class of "pip uninstall gutted a sibling wheel" breakage
# rather than just the symptom it produced in chipify/snp2le.

import csv
import sys
from importlib.metadata import distributions
from pathlib import Path

missing = {}

for dist in distributions():
    name = dist.metadata["Name"] or ""
    if not name.lower().startswith("pyside6"):
        continue
    record = dist.read_text("RECORD")
    if record is None:
        print(f"[WARNING] {name}: no RECORD, cannot verify")
        continue
    root = Path(dist.locate_file(""))
    gone = [
        row[0]
        for row in csv.reader(record.splitlines())
        if row and not (root / row[0]).exists()
    ]
    if gone:
        missing[f"{name} {dist.version}"] = gone

for dist, gone in missing.items():
    print(f"[ERROR] {dist}: {len(gone)} installed file(s) missing, e.g.:")
    for path in gone[:5]:
        print(f"          {path}")

if missing:
    sys.exit(1)

print("[INFO] All installed PySide6 distributions are complete on disk.")
