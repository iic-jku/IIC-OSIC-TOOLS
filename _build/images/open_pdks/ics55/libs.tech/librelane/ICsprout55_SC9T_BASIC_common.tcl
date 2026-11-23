# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Shared LibreLane configuration of the ICS55 v2 9-track standard cells
# ICsprout55_SC9T_BASIC_{SVT,HVT,LVT}. The three Vt flavours have the same
# cells and pins and differ only in the name suffix (_9TSVT, _9THVT, _9TLVT).

if { ![regexp {^ICsprout55_SC9T_BASIC_([SHL]VT)$} $::env(STD_CELL_LIBRARY) -> vt] } {
	error "ICsprout55_SC9T_BASIC_common.tcl sourced for '$::env(STD_CELL_LIBRARY)', which is not an ICsprout55_SC9T_BASIC library"
}
set sfx "_9T$vt"
set scl_tech_dir "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/librelane/$::env(STD_CELL_LIBRARY)"

set ::env(SYNTH_LATCH_MAP) "$scl_tech_dir/latch_map.v"
set ::env(SYNTH_MUX4_MAP) "$scl_tech_dir/mux4_map.v"
set ::env(SYNTH_MUX_MAP) "$scl_tech_dir/mux2_map.v"
set ::env(SYNTH_TRISTATE_MAP) "$scl_tech_dir/tribuff_map.v"

set ::env(PLACE_SITE) "SC9T_site"

# The cells have no well or substrate ties (VNW and VPW are separate pins).
# TAPX1 ties them to VDD and VSS, TAPVNPWX1 brings them out for body bias.
set ::env(WELLTAP_CELL) "TAPX1${sfx}"
set ::env(FP_TAPCELL_DIST) 15
# The library has no endcap cells, a one-site filler closes the implant and
# well layers at the row ends instead.
set ::env(ENDCAP_CELL) "FILL1${sfx}"

set ::env(SYNTH_DRIVING_CELL) "INVX8${sfx}/Y"
set ::env(OUTPUT_CAP_LOAD) 33.5
set ::env(SYNTH_BUFFER_CELL) "BUFX4${sfx}/A/Y"
set ::env(SYNTH_TIEHI_CELL) "TIEHIX1${sfx}/Y"
set ::env(SYNTH_TIELO_CELL) "TIELOX1${sfx}/Y"

set ::env(DIODE_CELL) "ANTENNAX1${sfx}/A"

# No decap cells: placed next to other cells, the internal node of FILLCAP*
# connects to the neighbour and the layout no longer matches the CDL (each
# FILLCAP matches on its own).
set ::env(DECAP_CELLS) [list]
set ::env(FILL_CELLS) [list "FILL1${sfx}" "FILL2${sfx}" "FILL4${sfx}" "FILL8${sfx}" "FILL16${sfx}" "FILL32${sfx}"]
set ::env(TRISTATE_CELLS) [list "TBUF*${sfx}"]

set ::env(GPL_CELL_PADDING) 0
set ::env(DPL_CELL_PADDING) 0
set ::env(CELL_PAD_EXCLUDE) [list "FILL*${sfx}" "TAP*${sfx}" "TIE*${sfx}" "ANTENNAX1${sfx}"]

# The G* spare cells (ECO gate array), the bus holder and the physical-only
# cells are kept out of synthesis and resizing.
set ::env(SYNTH_EXCLUDED_CELL_FILE) "$scl_tech_dir/synth_exclude.cells"
set ::env(PNR_EXCLUDED_CELL_FILE) "$scl_tech_dir/pnr_exclude.cells"

# The MET1 rails of the cells are 0.3 um wide (VDD at the top, VSS at the
# bottom of the 1.8 um row).
set ::env(PDN_RAIL_WIDTH) 0.3

set ::env(CTS_ROOT_BUFFER) "CLKBUFX16${sfx}"
set ::env(CTS_CLK_BUFFERS) [list "CLKBUFX4${sfx}" "CLKBUFX8${sfx}" "CLKBUFX16${sfx}"]

# Generic values (as in the IHP and sky130 configurations), not characterised
# for this process. The clock uncertainty is lower than their 0.25 ns: the
# shortest flop-to-flop paths of these cells are about 0.2 ns at tt, so 0.25 ns
# makes the hold repair buffer nearly every short path.
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(CLOCK_UNCERTAINTY_CONSTRAINT) 0.1
set ::env(CLOCK_TRANSITION_CONSTRAINT) 0.15
set ::env(TIME_DERATING_CONSTRAINT) 5
set ::env(IO_DELAY_CONSTRAINT) 20
