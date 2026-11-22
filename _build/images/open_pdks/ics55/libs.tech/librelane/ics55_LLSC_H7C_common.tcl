# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Shared LibreLane configuration of the 7-track standard cells
# ics55_LLSC_H7C{R,H,L}, adapted from ckdur/icsprout55-openpdk
# (libs.tech/librelane/ics55_LLSC_H7C_common.tcl, Apache-2.0). The three Vt
# flavours have the same cells and differ only in the name suffix.

if { ![regexp {^ics55_LLSC_H7C([RHL])$} $::env(STD_CELL_LIBRARY) -> vt] } {
	error "ics55_LLSC_H7C_common.tcl sourced for '$::env(STD_CELL_LIBRARY)', which is not an ics55_LLSC_H7C library"
}
set sfx "H7$vt"
set scl_tech_dir "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/librelane/$::env(STD_CELL_LIBRARY)"

set ::env(SYNTH_LATCH_MAP) "$scl_tech_dir/latch_map.v"
set ::env(SYNTH_MUX4_MAP) "$scl_tech_dir/mux4_map.v"
set ::env(SYNTH_MUX_MAP) "$scl_tech_dir/mux2_map.v"
set ::env(SYNTH_TRISTATE_MAP) "$scl_tech_dir/tribuff_map.v"

set ::env(PLACE_SITE) "core7"

set ::env(WELLTAP_CELL) "FILLTAP${sfx}"
set ::env(FP_TAPCELL_DIST) 15
# The library has no endcap cells
# (https://github.com/openecos-projects/ecos-studio/issues/47), a one-site
# filler closes the implant and well layers at the row ends instead.
set ::env(ENDCAP_CELL) "FILLER1${sfx}"

set ::env(SYNTH_DRIVING_CELL) "INVX8${sfx}/Y"
set ::env(OUTPUT_CAP_LOAD) 33.5
set ::env(SYNTH_BUFFER_CELL) "BUFX4${sfx}/A/Y"
set ::env(SYNTH_TIEHI_CELL) "TIEHI${sfx}/Z"
set ::env(SYNTH_TIELO_CELL) "TIELO${sfx}/Z"

# Only FILLCAP4: the larger decap cells pick up an extra pin from their
# neighbours in a placed row and then fail LVS (the port reports DRC
# violations for them as well).
set ::env(DECAP_CELLS) [list "FILLCAP4${sfx}"]
set ::env(FILL_CELLS) [list "FILLER*${sfx}"]

set ::env(GPL_CELL_PADDING) 0
set ::env(DPL_CELL_PADDING) 0
set ::env(CELL_PAD_EXCLUDE) [list "FILLCAP*${sfx}" "TIEHI${sfx}" "TIELO${sfx}"]

# Cells whose layout does not match their CDL or that fail the port's DRC
# (lists of ckdur/icsprout55-openpdk).
set ::env(SYNTH_EXCLUDED_CELL_FILE) "$scl_tech_dir/synth_exclude.cells"
set ::env(PNR_EXCLUDED_CELL_FILE) "$scl_tech_dir/pnr_exclude.cells"

set ::env(PDN_RAIL_WIDTH) 0.16

set ::env(CTS_ROOT_BUFFER) "BUFX16${sfx}"
set ::env(CTS_CLK_BUFFERS) [list "BUFX4${sfx}" "BUFX8${sfx}" "BUFX16${sfx}"]

# Generic values (as in the IHP and sky130 configurations), not characterised
# for this process.
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(CLOCK_UNCERTAINTY_CONSTRAINT) 0.25
set ::env(CLOCK_TRANSITION_CONSTRAINT) 0.15
set ::env(TIME_DERATING_CONSTRAINT) 5
set ::env(IO_DELAY_CONSTRAINT) 20
