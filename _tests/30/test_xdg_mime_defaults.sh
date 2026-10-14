#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Check that every design file type opens in the right application.
#
# Two things have to hold for a double click in Thunar, an `xdg-open`, or a
# button in sak-open to reach the intended tool:
#
#   1. the extension resolves to the intended MIME type, which for the EDA
#      formats comes from skel/usr/share/mime/packages/iic-osic-tools-types.xml
#      and only works if update-mime-database ran after that file was copied in;
#   2. that MIME type has a default application, which comes from
#      skel/usr/share/applications/mimeapps.list.
#
# Both have failed silently before: the MIME package shipped uncompiled (a .sch
# resolved as text/plain), .gds.gz lost to the generic "*.gz" glob and opened in
# the archive manager, and the many types no installed application claims had no
# handler at all.
#
# The test also asserts that sak-open.py knows no file type this list does not
# cover, so extending the one without the other fails here.
#
# .mag.gz is deliberately absent: magic cannot read a gzipped layout, so neither
# the MIME package nor sak-open.py claims one.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

set -euo pipefail

SAK_OPEN="/foss/tools/sak/sak-open.py"

# <probe file name> <expected .desktop file>
# A row is a file name, not only an extension, so entries that carry no
# extension at all (Makefile) can be expressed the same way.
EXPECTED="
probe.sch     xschem.desktop
probe.sym     xschem.desktop
probe.gds     klayout.desktop
probe.gds.gz  klayout.desktop
probe.oas     klayout.desktop
probe.oas.gz  klayout.desktop
probe.mag     magic.desktop
probe.vcd     gtkwave.desktop
probe.fst     gtkwave.desktop
probe.gtkw    gtkwave.desktop
probe.raw     gaw.desktop
probe.png     org.xfce.ristretto.desktop
probe.pdf     org.pwmt.zathura.desktop
probe.sv      gvim.desktop
probe.svh     gvim.desktop
probe.v       gvim.desktop
probe.vh      gvim.desktop
probe.vhd     gvim.desktop
probe.vhdl    gvim.desktop
probe.spice   gvim.desktop
probe.cir     gvim.desktop
probe.sp      gvim.desktop
probe.cdl     gvim.desktop
probe.sdc     gvim.desktop
probe.lef     gvim.desktop
probe.lib     gvim.desktop
probe.tcl     gvim.desktop
probe.mk      gvim.desktop
probe.yaml    gvim.desktop
probe.json    gvim.desktop
probe.py      gvim.desktop
probe.qmd     gvim.desktop
probe.tex     gvim.desktop
probe.md      gvim.desktop
probe.bib     gvim.desktop
probe.log     gvim.desktop
probe.toml    gvim.desktop
probe.js      gvim.desktop
probe.scala   gvim.desktop
probe.sh      gvim.desktop
probe.ps      gv.desktop
probe.eps     gv.desktop
Makefile      gvim.desktop
"

for cmd in xdg-mime python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] $cmd is not installed or not in PATH."
        exit 1
    fi
done

TMP=${RUNS_DIR}/${RAND}/30
LOG=${TMP}/test_xdg_mime_defaults.log

mkdir -p "$TMP"
cd "$TMP" || { echo "[ERROR] Failed to change directory to $TMP."; exit 1; }
: > "$LOG"

FAILED=0

# The probe files are empty, so nothing is decided by content sniffing: this
# checks the name routing, which is what a user's file name gives us.
while read -r PROBE WANT; do
    [ -z "$PROBE" ] && continue
    : > "$PROBE"
    TYPE=$(xdg-mime query filetype "$PROBE" 2>>"$LOG" | head -1)
    GOT=$(xdg-mime query default "$TYPE" 2>>"$LOG" | head -1)
    printf "%-14s %-34s %s\n" "$PROBE" "${TYPE:-<none>}" "${GOT:-<none>}" >> "$LOG"
    if [ "$GOT" != "$WANT" ]; then
        echo "[ERROR] $PROBE resolves to <${TYPE:-none}> handled by <${GOT:-none}>, expected <$WANT>."
        FAILED=1
    fi
done <<< "$EXPECTED"

# Every application named above has to exist, otherwise the association points
# at nothing and xdg-open falls through to its next candidate.
for DESKTOP in $(echo "$EXPECTED" | awk 'NF {print $2}' | sort -u); do
    if [ ! -f "/usr/share/applications/$DESKTOP" ]; then
        echo "[ERROR] Desktop entry </usr/share/applications/$DESKTOP> is missing."
        FAILED=1
    fi
done

# sak-open.py must not know a file type this test does not cover.
if [ ! -f "$SAK_OPEN" ]; then
    echo "[ERROR] <$SAK_OPEN> not found."
    exit 1
fi
# Its VIEWERS keys are either a suffix (".sv") or a whole file name
# ("Makefile"), which map onto the probe names of the table above.
SAK_PROBES=$(python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('sak_open', '$SAK_OPEN')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print('\n'.join(sorted('probe' + k if k.startswith('.') else k for k in mod.VIEWERS)))
")
for PROBE in $SAK_PROBES; do
    if ! echo "$EXPECTED" | awk 'NF {print $1}' | grep -qx "$PROBE"; then
        echo "[ERROR] sak-open.py handles <$PROBE>, but this test has no expectation for it."
        FAILED=1
    fi
done

if [ "$FAILED" -ne 0 ]; then
    echo "[ERROR] Test <xdg-mime defaults> failed. See <$LOG> for the full table."
    exit 1
fi

echo "[INFO] Test <xdg-mime defaults> passed."
exit 0
