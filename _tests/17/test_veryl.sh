#!/bin/bash
# SPDX-FileCopyrightText: 2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test Veryl with a simple example

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP=/foss/designs/runs/${RAND}/17
mkdir -p "$TEMP"
cd "$TEMP" || exit 1

# Install Veryl if not already installed
if ! command -v veryl >/dev/null 2>&1; then
    export PATH="$PATH:$XDG_DATA_HOME/veryl/toolchains/latest"
    verylup --quiet install latest
fi

veryl --quiet new test > /dev/null
cp "$DIR/HalfAdder.veryl" "$TEMP/test/src"
cd test || exit 1

veryl --quiet build > /dev/null

# Check if there is an error in the build
if [ ! -f ./target/HalfAdder.sv ]; then
    echo "[ERROR] Test <Veryl> FAILED."
    exit 1
else
    echo "[INFO] Test <Veryl> passed."
fi

# Cleanup
exit 0
