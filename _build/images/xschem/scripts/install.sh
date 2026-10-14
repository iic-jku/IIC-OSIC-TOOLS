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

# Require the Ctrl key for zoom/pan inside graph (waveform) widgets, so plain mouse
# wheel scrolling keeps zooming the schematic when the pointer happens to be over a
# graph. This is a PDK-independent UI preference, so it goes into the system-wide
# xschemrc. It is set from postinit_commands for the same reason as above: the user
# xschemrc sources the PDK xschemrc, so PDK files are evaluated after this one and a
# plain "set" here could be overridden. The value is read at event time, so setting it
# in postinit_commands takes effect for the whole session; the Options menu toggle
# still works for anyone who wants the default behavior back.
cat >> "${TOOLS}/${XSCHEM_NAME}/share/xschem/xschemrc" <<'EOF'

###########################################################################
#### USE CTRL KEY FOR ZOOM/PAN IN GRAPHS
###########################################################################
append postinit_commands {
  set graph_use_ctrl_key 1
}
EOF

# Let xschem run the Tcl scripts embedded in schematics and symbols without putting
# up a confirmation dialog, which the PDK launcher symbols and the tcleval() attributes
# need in order to work silently. This has to live in the system-wide xschemrc, because
# that is the only file xschem is guaranteed to read: after sourcing it, xschem sources
# exactly one of ./xschemrc in the directory it was started in or ~/.xschem/xschemrc,
# whichever it finds first, and never both. Every IIC design template ships a
# project-local xschemrc, so the shipped user xschemrc is shadowed in most real
# sessions. A plain "set" is enough here, unlike the two settings above: none of the
# packaged PDK xschemrc files touches the variable, so nothing sourced later overrides
# it, and the value is only read when a schematic is loaded, which happens after the
# whole rc chain has run.
cat >> "${TOOLS}/${XSCHEM_NAME}/share/xschem/xschemrc" <<'EOF'

###########################################################################
#### ALLOW EMBEDDED TCL SCRIPTS WITHOUT ASKING
###########################################################################
set xschem_execute_scripts yes
EOF

echo "${XSCHEM_NAME} ${XSCHEM_REPO_COMMIT}" > "${TOOLS}/${XSCHEM_NAME}/SOURCES"
