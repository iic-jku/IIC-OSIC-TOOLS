#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# PyOPUS requires these packages be installed via APT: python3-cvxopt and python3-pyqt5
# (otherwise build fails on aarch64). python3-pyqt5 is a base-dev package and does
# not reach the runtime image -- the installed sources are ported to PySide6 below.
mkdir -p "$TOOLS"
cd /tmp || exit 1 
wget --no-verbose "$PYOPUS_REPO_URL/$PYOPUS_REPO_COMMIT/pyopus-$PYOPUS_REPO_COMMIT.tar.gz"
tar xfz "pyopus-$PYOPUS_REPO_COMMIT.tar.gz"
cd "pyopus-$PYOPUS_REPO_COMMIT" || exit 1
pip3 install . --prefix="$TOOLS/$PYOPUS_NAME" --no-cache-dir
ln -s "$TOOLS/$PYOPUS_NAME/local/bin" "$TOOLS/$PYOPUS_NAME/bin"

# ---------------------------------------------------------------------------
# Port the installed sources from PyQt5 to PySide6
#
# PySide6 is the image's only Python Qt binding (install_eda.sh installs it for
# chipify/snp2le/gds2palace/setupEM); python3-pyqt5 exists in base-dev for the
# build above but not in the runtime image. PyOPUS 0.12 is written against
# PyQt5, so rewrite it here. The sources have CRLF line endings, which the
# line-oriented tools below preserve.
#
# The GUI (pyopus.gui, launched by pyog) is NOT ported: its 14 table models
# assign a dict to self.data, shadowing QAbstractTableModel.data(). PyQt5 still
# dispatches the virtual to the class method, PySide6 finds the instance
# attribute and raises "'dict' object is not callable" as soon as an editor
# opens. Un-shadowing that is a fork of the GUI, not a port, so it is removed
# (except for gui/style.py, which the plotter imports). pyopus.plotter (the
# threaded live plotting used by the demos) and pyopus.netlister are ported
# and keep working.
# ---------------------------------------------------------------------------
PYOPUS_PKG=$(find "$TOOLS/$PYOPUS_NAME" -type d -name pyopus -path '*/dist-packages/*' | head -1)
[ -n "$PYOPUS_PKG" ] || { echo "[ERROR] installed pyopus package not found"; exit 1; }

echo "[INFO] Removing the PyQt5-only PyOPUS GUI"
# gui/style.py holds the stylesheet helpers and is imported by the plotter's
# control window, so it (and the package __init__) has to stay behind.
find "$PYOPUS_PKG/gui" -mindepth 1 -maxdepth 1 \
	! -name '__init__.py' ! -name 'style.py' -exec rm -rf {} +
rm -f "$TOOLS/$PYOPUS_NAME/local/bin/pyog"

echo "[INFO] Porting PyOPUS from PyQt5 to PySide6"
find "$PYOPUS_PKG" -name '*.py' -print0 | xargs -0 sed -i \
	-e 's/\bPyQt5\b/PySide6/g' \
	-e 's/\bpyqtSignal\b/Signal/g' \
	-e 's/\bpyqtSlot\b/Slot/g' \
	-e 's/\bpyqtProperty\b/Property/g' \
	-e "s/matplotlib\.use('Qt5Agg')/matplotlib.use('QtAgg')/" \
	-e 's/\bbackend_qt5agg\b/backend_qtagg/g' \
	-e 's/\bQDesktopWidget()/QApplication.primaryScreen()/g' \
	-e 's/\bqApp\b/QApplication.instance()/g' \
	-e 's/\bPyQt_PyObject\b/PyObject/g' \
	-e 's/^\(\s*\)import sip\s*$/\1sip = None  # PySide6 has no sip/' \
	-e 's/\bsip\.setdestroyonexit(False)/pass  # PySide6: no sip.setdestroyonexit/'

python3 - "$PYOPUS_PKG" <<'PYEOF'
import pathlib
import re
import sys

pkg = pathlib.Path(sys.argv[1])

# PySide6 refuses to carry a Python object through QMetaMethod.invoke()
# ("qArgDataFromPyType: Unable to find a QMetaType for object"), which is how
# PyOPUS hands a plotting command from the main thread to the GUI thread. A
# Signal(object) with a BlockingQueuedConnection has the same semantics and
# does work, so replace the meta-object plumbing with a poster object.
f = pkg / "plotter" / "manager.py"
src = f.read_text()
nl = "\r\n" if "\r\n" in src else "\n"

setup = [
	"\t\t\t# Poster object living in this (the calling) thread. Its signal is",
	"\t\t\t# delivered to processMessage() in the GUI thread.",
	"\t\t\tfrom PySide6 import QtCore",
	"",
	"\t\t\tclass _MessagePoster(QtCore.QObject):",
	"\t\t\t\tmessage=QtCore.Signal(object)",
	"",
	"\t\t\tself.messagePoster=_MessagePoster()",
	"\t\t\tself.messagePoster.message.connect(",
	"\t\t\t\tself.controlWindow.processMessage, QtCore.Qt.BlockingQueuedConnection",
	"\t\t\t)",
	"",
]
post = ["\t\t\tself.messagePoster.message.emit(message)", ""]

patches = (
	(re.compile(r"\t+# Get meta object for the control app.*?\n\t\t\t\)\r?\n", re.S), setup),
	(re.compile(r"\t+self\.cwMetaProcessMessage\.invoke\(.*?\n\t\t\t\)\r?\n", re.S), post),
)
for pattern, lines in patches:
	src, n = pattern.subn(nl.join(lines), src, count=1)
	if n != 1:
		sys.exit("PySide6 port: expected block not found in %s" % f)
f.write_text(src)

# QVariant, which PySide6 does not expose, was used only by the removed GUI.
leftover = [str(p) for p in pkg.rglob("*.py") if "QVariant" in p.read_text()]
if leftover:
	sys.exit("PySide6 port: QVariant still used by %s" % ", ".join(leftover))
PYEOF

# Drop the .pyc files pip generated from the pre-port sources
find "$PYOPUS_PKG" -name '__pycache__' -type d -prune -exec rm -rf {} +

if grep -rq '\bPyQt5\b' "$PYOPUS_PKG" --include='*.py'; then
	echo "[ERROR] PyQt5 references remain in the installed PyOPUS sources"
	grep -rn '\bPyQt5\b' "$PYOPUS_PKG" --include='*.py'
	exit 1
fi

# Cleanup compile dir
cd /tmp && rm -rf "pyopus-$PYOPUS_REPO_COMMIT" && rm -f "pyopus-$PYOPUS_REPO_COMMIT.tar.gz"

# Install examples and docs
cd /tmp || exit 1
wget --no-verbose "$PYOPUS_REPO_URL/$PYOPUS_REPO_COMMIT/PyOPUS-$PYOPUS_REPO_COMMIT-doc-demo.tar.gz"
tar xfz "PyOPUS-$PYOPUS_REPO_COMMIT-doc-demo.tar.gz"
cd "PyOPUS-$PYOPUS_REPO_COMMIT" || exit 1
mv demo "$TOOLS/$PYOPUS_NAME/demo"
mv docsrc/_build/html "$TOOLS/$PYOPUS_NAME/doc" 

# Cleanup doc and demo dir
cd /tmp && rm -rf "PyOPUS-$PYOPUS_REPO_COMMIT" && rm -f "PyOPUS-$PYOPUS_REPO_COMMIT-doc-demo.tar.gz"

echo "${PYOPUS_NAME} ${PYOPUS_REPO_COMMIT}" > "${TOOLS}/${PYOPUS_NAME}/SOURCES"
