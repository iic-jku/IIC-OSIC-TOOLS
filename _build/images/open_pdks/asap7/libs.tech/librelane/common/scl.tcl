# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# LibreLane standard-cell configuration shared by the threshold flavors of
# asap7sc7p5t. The flavor configs set asap7_vt (R, L or SL) and source this
# file. Cell choices follow the OpenROAD-flow-scripts platform asap7.

set common "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/librelane/common"
set ref "$::env(PDK_ROOT)/$::env(PDK)/libs.ref/asap7sc7p5t"
set vt $asap7_vt
set lib_vt "${vt}VT"
if { $vt eq "SL" } {
    set lib_vt "SLVT"
}

# Liberty, NLDM, one file per cell group
set ::env(CELL_LIBS) [dict create]
foreach {pattern corner} {
    "*_tt_0p70V_25C"  TT
    "*_ff_0p77V_0C"   FF
    "*_ss_0p63V_100C" SS
} {
    set libs [list \
        "$ref/lib/asap7sc7p5t_AO_${lib_vt}_${corner}_nldm_211120.lib.gz" \
        "$ref/lib/asap7sc7p5t_INVBUF_${lib_vt}_${corner}_nldm_220122.lib.gz" \
        "$ref/lib/asap7sc7p5t_OA_${lib_vt}_${corner}_nldm_211120.lib.gz" \
        "$ref/lib/asap7sc7p5t_SEQ_${lib_vt}_${corner}_nldm_220123.lib.gz" \
        "$ref/lib/asap7sc7p5t_SIMPLE_${lib_vt}_${corner}_nldm_211120.lib.gz" \
    ]
    dict set ::env(CELL_LIBS) $pattern $libs
}

set ::env(CELL_LEFS) "$ref/lef/asap7sc7p5t_28_${vt}_1x_220121a.lef"
set ::env(CELL_GDS) "$ref/gds/asap7sc7p5t_28_${vt}_220121a.gds"
set ::env(CELL_CDLS) "$ref/cdl/asap7sc7p5t_28_${vt}.cdl"
set ::env(CELL_VERILOG_MODELS) [glob "$ref/verilog/asap7sc7p5t_*_${lib_vt}_TT_*.v"]

# Synthesis mapping
set ::env(SYNTH_LATCH_MAP) "$common/cells_latch_${vt}.v"
set ::env(SYNTH_FA_MAP) "$common/cells_adders_${vt}.v"

set ::env(PLACE_SITE) "asap7sc7p5t"

# Tap and endcap cells
set ::env(WELLTAP_CELL) "TAPCELL_ASAP7_75t_${vt}"
set ::env(ENDCAP_CELL) "TAPCELL_ASAP7_75t_${vt}"

# Defaults, can be overridden by designs
set ::env(SYNTH_DRIVING_CELL) "BUFx2_ASAP7_75t_${vt}/Y"
set ::env(SYNTH_CLK_DRIVING_CELL) "BUFx4_ASAP7_75t_${vt}/Y"
set ::env(SYNTH_BUFFER_CELL) "BUFx2_ASAP7_75t_${vt}/A/Y"
set ::env(SYNTH_TIEHI_CELL) "TIEHIx1_ASAP7_75t_${vt}/H"
set ::env(SYNTH_TIELO_CELL) "TIELOx1_ASAP7_75t_${vt}/L"
# Pin A of INVx8_ASAP7_75t_R in fF. Yosys/ABC reads this in fF, the LibreLane
# base SDC divides it by 1000 for a pF library, so OpenSTA sees 1/1000 of it
# with the fF Liberty of ASAP7.
set ::env(OUTPUT_CAP_LOAD) "4.61057"

# Same exclusions as ORFS DONT_USE_CELLS: sub-x1 sizes ease congestion, scan
# flops and clock gates are not used by synthesis
set ::env(SYNTH_EXCLUDED_CELL_FILE) "$common/synth_exclude.cells"
set ::env(PNR_EXCLUDED_CELL_FILE) "$common/synth_exclude.cells"

# Fill and decap cells
set ::env(FILL_CELLS) "FILLERxp5_ASAP7_75t_${vt} FILLER_ASAP7_75t_${vt}"
set ::env(DECAP_CELLS) "DECAPx1_ASAP7_75t_${vt} DECAPx2_ASAP7_75t_${vt} DECAPx4_ASAP7_75t_${vt} DECAPx6_ASAP7_75t_${vt} DECAPx10_ASAP7_75t_${vt}"
set ::env(CELL_PAD_EXCLUDE) "FILLER* DECAP* TAPCELL*"

set ::env(GPL_CELL_PADDING) 0
set ::env(DPL_CELL_PADDING) 0

# ASAP7 has no antenna rules and no diode cell, designs set
# "RUN_ANTENNA_REPAIR": false (DIODE_CELL stays unset)

# CTS
set ::env(CTS_ROOT_BUFFER) "BUFx4_ASAP7_75t_${vt}"
set ::env(CTS_CLK_BUFFERS) "BUFx4_ASAP7_75t_${vt} BUFx2_ASAP7_75t_${vt}"

# Constraint defaults in ps (Liberty time unit of ASAP7), DEFAULT_MAX_TRAN as
# in ORFS
set ::env(MAX_FANOUT_CONSTRAINT) 10
set ::env(CLOCK_UNCERTAINTY_CONSTRAINT) 10
set ::env(CLOCK_TRANSITION_CONSTRAINT) 50
set ::env(TIME_DERATING_CONSTRAINT) 5
set ::env(IO_DELAY_CONSTRAINT) 20
set ::env(DEFAULT_MAX_TRAN) 320

# Tristate cells
set ::env(TRISTATE_CELLS) "TBUFx*_ASAP7_75t_${vt}"

set ::env(HEURISTIC_ANTENNA_THRESHOLD) 1000

unset common ref vt lib_vt libs pattern corner
