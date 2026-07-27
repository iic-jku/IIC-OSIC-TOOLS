#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XSCHEM_REPO_URL}" "${XSCHEM_NAME}"
cd "${XSCHEM_NAME}" || exit 1
git checkout "${XSCHEM_REPO_COMMIT}"

# Upstream commit 36d710d2 ("Ask user before allowing execution of embedded schematic
# scripts") added an unguarded Tk `focus` call to `proc tclpropeval2` in src/xschem.tcl.
# tclpropeval2 evaluates `tcleval(...)` properties, which the IHP PDK uses for its
# annotate_fet_params/annotate_bip_params symbols. When xschem runs headless (--no_x)
# Tk is not loaded, so `focus` does not exist and every tcleval() property aborts with
#   tclvareval(): error executing tclpropeval2 {tcleval([display_fet_params M2A ])}:
#   invalid command name "focus"
# which breaks batch netlisting of any schematic carrying such an annotation.
# The `ask` branch right above it is already guarded by `has_x`; guard `focus` the same
# way. Drop this patch once xschem fixes it upstream.
python3 - src/xschem.tcl << 'PYEOF'
import sys
fname = sys.argv[1]
old = '    focus [xschem get top_path].drw\n'
new = '    if {[info exists has_x]} { focus [xschem get top_path].drw }\n'
with open(fname) as f:
    content = f.read()
if new in content:
    print("[INFO] xschem tclpropeval2 focus guard already present, nothing to do.")
elif content.count(old) == 1:
    with open(fname, 'w') as f:
        f.write(content.replace(old, new))
    print(f"[INFO] Guarded the headless-unsafe focus call in {fname}.")
else:
    print(f"[WARN] Unguarded focus call not found in {fname} "
          f"({content.count(old)} matches) - patch may be obsolete, please re-check.")
PYEOF

./configure --prefix="${TOOLS}/${XSCHEM_NAME}"

# xschem's src/Makefile declares "expandlabel.c expandlabel.h: expandlabel.y" as a
# multi-target rule with a single bison recipe. Under "make -j" GNU make treats this
# as two independent rules and can launch bison twice concurrently (once for the .c
# needed by expandlabel.o, once for the .h needed by parselabel.o). One invocation
# then truncates expandlabel.c while gcc is compiling it, failing the build with a
# bogus "unterminated comment" error. Generate the bison/flex sources serially first,
# then compile everything in parallel.
make -C src expandlabel.c expandlabel.h eval_expr.c parselabel.c
make -j"$(nproc)"
make install

# Enable the "analyses" symbol library that ships with xschem, so VACASK and ngspice
# simulations can be set up visually (op, ac, tran, sweep, command_block, ...) instead
# of by hand-writing a control block. The library is PDK-independent, so it is enabled
# in the system-wide xschemrc: that file is always sourced, and it is sourced before
# any project, user, or PDK xschemrc. Both steps run in postinit_commands because the
# PDK xschemrc files reset XSCHEM_LIBRARY_PATH to {} when they are sourced later during
# startup, which would drop a path appended here. Sourcing lib_init.tcl is required as
# well: it defines the procs that render the symbols and netlist the control block.
# See https://codeberg.org/arpadbuermen/VACASK/src/branch/main/demo/xschem for details.
cat >> "${TOOLS}/${XSCHEM_NAME}/share/xschem/xschemrc" <<'EOF'

###########################################################################
#### VISUAL ANALYSIS SETUP LIBRARY (VACASK AND NGSPICE)
###########################################################################
append postinit_commands {
  set iic_analyses_dir [file normalize ${XSCHEM_SHAREDIR}/../doc/xschem/analyses]
  if {[file isdirectory $iic_analyses_dir] && [lsearch -exact $pathlist $iic_analyses_dir] < 0} {
    # Writing XSCHEM_LIBRARY_PATH refreshes pathlist through a variable trace.
    append XSCHEM_LIBRARY_PATH :$iic_analyses_dir
  }
  unset iic_analyses_dir
  foreach i $pathlist {
    if {![catch {source $i/lib_init.tcl} retval]} {
      puts "Sourced library init file $i/lib_init.tcl"
    }
  }
}
EOF

echo "${XSCHEM_NAME} ${XSCHEM_REPO_COMMIT}" > "${TOOLS}/${XSCHEM_NAME}/SOURCES"
