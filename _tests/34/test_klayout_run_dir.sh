#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Regression test for the KLayout GUI DRC/LVS run directory patch that
# install_ihp.sh and install_ihp_cmos5l.sh apply to both IHP PDKs
# (fix_klayout_run_dir.py).
#
# The patch is applied by matching the shipped macro text, and a PDK bump that
# rewrites those lines makes it silently skip. This test is that alarm: it
# checks the installed macros carry the fix, that no one-argument
# File.expand_path is left to resolve a run directory against the working
# directory again, that the resolution behaves as intended, and that the
# patched macros are still valid XML and valid Ruby.
#
# Only the verdict is printed on the console; the per-case results and the full
# command output go into the log. Set SAK_TEST_VERBOSE=1 to see every case.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

WORKDIR=${RUNS_DIR}/${RAND}/34
LOG=$WORKDIR/klayout_run_dir_test.log
mkdir -p "$WORKDIR"
: > "$LOG"

PASS=0
FAIL=0
VERBOSE=${SAK_TEST_VERBOSE:-0}

report() {
    local line=$1
    local failed=$2
    echo "$line" >> "$LOG"
    if [ "$failed" -ne 0 ] || [ "$VERBOSE" -ne 0 ]; then
        echo "$line"
    fi
}

check() {
    local name=$1
    local expect=$2
    shift 2
    {
        echo "===================================================================="
        echo "==== TEST: $name (expect exit $expect)"
        echo "==== CMD : $*"
    } >> "$LOG"
    "$@" >> "$LOG" 2>&1
    local rc=$?
    echo "==== EXIT: $rc" >> "$LOG"
    if [ "$rc" -eq "$expect" ]; then
        PASS=$((PASS+1))
        report "[PASS] $name" 0
    else
        FAIL=$((FAIL+1))
        report "[FAIL] $name (exit $rc, expected $expect)" 1
    fi
}

# The macro body is XML-escaped inside the .lym, so unescape it before handing
# it to ruby -c. Doubles as the XML well-formedness check.
cat > "$WORKDIR/lym2rb.py" << 'PYEOF'
import sys
import xml.etree.ElementTree as ET

body = ET.parse(sys.argv[1]).getroot().find("text").text or ""
with open(sys.argv[2], "w") as f:
    f.write(body)
PYEOF

# Reproduces the patched DRC resolution with the surrounding variables stubbed,
# run from a working directory that has nothing to do with the layout.
cat > "$WORKDIR/resolve.rb" << 'RBEOF'
opt = ARGV[0]
gds_path = ARGV[1]
top_cell = ARGV[2]
run_dir_base = gds_path.to_s.empty? ? Dir.pwd : File.dirname(File.expand_path(gds_path.to_s))
safe_top = top_cell.to_s.gsub(/[^A-Za-z0-9_.-]/, '_')
run_dir = opt
if run_dir.nil? || run_dir.strip.empty?
  if File.directory?(File.expand_path('../verification', run_dir_base))
    run_dir = "../verification/drc/#{safe_top}.klayout-gui.drc"
  else
    run_dir = "drc_run_#{top_cell}"
  end
end
puts File.expand_path(run_dir.gsub('%top_cell%', safe_top), run_dir_base)
RBEOF

for PDK in ihp-sg13g2 ihp-sg13cmos5l; do
    PREFIX=${PDK#ihp-}
    MACROS=${PDK_ROOT:-/foss/pdks}/$PDK/libs.tech/klayout/tech/macros

    check "$PDK: macro directory present" 0 \
        bash -c "[ -d '$MACROS' ]"

    for KIND in drc lvs; do
        LYM=$MACROS/${PREFIX}_${KIND}.lym

        check "$PDK: ${KIND}.lym resolves against the layout" 0 \
            grep -q "^run_dir_base = " "$LYM"
        check "$PDK: ${KIND}.lym substitutes %top_cell%" 0 \
            grep -q "gsub('%top_cell%'" "$LYM"
        # the one-argument form is what resolved against the working directory
        check "$PDK: ${KIND}.lym has no cwd-relative expand_path" 1 \
            grep -qE "File\.expand_path\(run_dir\)" "$LYM"
        check "$PDK: ${KIND}.lym defaults into a sibling verification folder" 0 \
            grep -q "File.directory?(File.expand_path('../verification', run_dir_base))" "$LYM"
        # a menu run must never land on the batch <cell>.klayout.<kind> that
        # sak-drc.sh and sak-lvs.sh write, the DRC macro deletes its run dir
        check "$PDK: ${KIND}.lym tags the default so it cannot hit the batch run" 0 \
            grep -q "klayout-gui.${KIND}" "$LYM"

        OPT=$MACROS/${PREFIX}_${KIND}_options.lym
        check "$PDK: ${KIND} options document %top_cell%" 0 \
            grep -q "%top_cell%" "$OPT"

        for F in "$LYM" "$OPT"; do
            RB=$WORKDIR/$(basename "$F" .lym).rb
            check "$PDK: $(basename "$F") is valid XML" 0 \
                python3 "$WORKDIR/lym2rb.py" "$F" "$RB"
            check "$PDK: $(basename "$F") is valid Ruby" 0 \
                ruby -c "$RB"
        done
    done
done

# The resolution itself, from an unrelated working directory.
mkdir -p "$WORKDIR/elsewhere"
cd "$WORKDIR/elsewhere" || exit 1

expect() {
    local name=$1
    local want=$2
    shift 2
    local got
    got=$(ruby "$WORKDIR/resolve.rb" "$@" 2>> "$LOG")
    echo "==== $name -> $got" >> "$LOG"
    if [ "$got" = "$want" ]; then
        PASS=$((PASS+1))
        report "[PASS] $name" 0
    else
        FAIL=$((FAIL+1))
        report "[FAIL] $name (got $got, wanted $want)" 1
    fi
}

expect "relative run_dir follows the layout, not the cwd" \
    "/p/verification/drc/inv.klayout.drc" \
    "../verification/drc/%top_cell%.klayout.drc" "/p/layout/inv.gds" "inv"
expect "absolute run_dir is left alone" \
    "/tmp/fixed" "/tmp/fixed" "/p/layout/inv.gds" "inv"
expect "an explicit relative run_dir lands next to the layout" \
    "/p/layout/drc_run_inv" "drc_run_inv" "/p/layout/inv.gds" "inv"
expect "no layout falls back to the cwd" \
    "$WORKDIR/elsewhere/out" "out" "" "inv"
expect "a cell name is sanitized into one path component" \
    "/p/layout/v/a_b" "v/%top_cell%" "/p/layout/inv.gds" "a/b"

# The default follows the project: a verification folder beside the layout
# folder takes the reports, anything else keeps them next to the layout.
PROJ=$WORKDIR/proj
mkdir -p "$PROJ/layout" "$PROJ/verification" "$PROJ/final/gds"
: > "$PROJ/layout/inv.gds"
: > "$PROJ/final/gds/inv.gds"

expect "empty run_dir uses the sibling verification folder" \
    "$PROJ/verification/drc/inv.klayout-gui.drc" "" "$PROJ/layout/inv.gds" "inv"
expect "empty run_dir stays next to a layout with no verification sibling" \
    "$PROJ/final/gds/drc_run_inv" "" "$PROJ/final/gds/inv.gds" "inv"
expect "the default never lands on the batch <cell>.klayout.drc" \
    "$PROJ/verification/drc/inv.klayout-gui.drc" "" "$PROJ/layout/inv.gds" "inv"
expect "an explicit setting still overrides the project default" \
    "$PROJ/verification/drc/inv.klayout.drc" \
    "../verification/drc/%top_cell%.klayout.drc" "$PROJ/layout/inv.gds" "inv"

if [ "$FAIL" -ne 0 ]; then
    echo "[ERROR] Test <KLayout GUI run directory> FAILED! $PASS passed, $FAIL failed. Check the log file $LOG for details."
    exit 1
else
    echo "[INFO] Test <KLayout GUI run directory> passed ($PASS checks)."
    exit 0
fi
