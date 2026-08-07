#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test Veryl with a simple example

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP=${RUNS_DIR}/${RAND}/17
mkdir -p "$TEMP"
cd "$TEMP" || exit 1

# The veryl/veryl-ls proxies and the default toolchain are preinstalled in
# the image by verylup setup at build time; install on demand as a fallback.
if ! command -v veryl >/dev/null 2>&1; then
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
