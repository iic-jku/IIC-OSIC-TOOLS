#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
cd /tmp || exit 1

git clone --filter=blob:none "${XSCHEM_REPO_URL}" "${XSCHEM_NAME}"
cd "${XSCHEM_NAME}" || exit 1
git checkout "${XSCHEM_REPO_COMMIT}"
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
