#!/bin/bash
set -e

# PyOPUS requires these packages be installed via APT: python3-cvxopt and python3-pyqt5
# (otherwise build fails on aarch64)
mkdir -p "$TOOLS"
cd /tmp || exit 1 
wget --no-verbose "$PYOPUS_REPO_URL/$PYOPUS_REPO_COMMIT/PyOPUS-$PYOPUS_REPO_COMMIT.tar.gz"
tar xfz "PyOPUS-$PYOPUS_REPO_COMMIT.tar.gz"
cd "PyOPUS-$PYOPUS_REPO_COMMIT" || exit 1
pip3 install . --prefix="$TOOLS/$PYOPUS_NAME" --no-cache-dir
ln -s "$TOOLS/$PYOPUS_NAME/local/bin" "$TOOLS/$PYOPUS_NAME/bin" 

# Cleanup compile dir
cd /tmp && rm -rf "PyOPUS-$PYOPUS_REPO_COMMIT" 

# Install examples and docs
cd /tmp || exit 1
wget --no-verbose "$PYOPUS_REPO_URL/$PYOPUS_REPO_COMMIT/PyOPUS-$PYOPUS_REPO_COMMIT-doc-demo.tar.gz"
tar xfz "PyOPUS-$PYOPUS_REPO_COMMIT-doc-demo.tar.gz"
cd "PyOPUS-$PYOPUS_REPO_COMMIT" || exit 1
mv demo "$TOOLS/$PYOPUS_NAME/demo"
mv docsrc/_build/html "$TOOLS/$PYOPUS_NAME/doc" 

# Make symlinks for binaries
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .

