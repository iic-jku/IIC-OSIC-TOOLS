# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# LibreLane PDK configuration of ICS55 v2 (digital-only), first adapted from
# ckdur/icsprout55-openpdk (libs.tech/librelane/config.tcl, Apache-2.0).
#
# The vendor standard cells as released, no RCX rules (the vendor publishes no
# extraction data), no Magic or Netgen collateral. A design configuration
# therefore has to switch off the Magic, LVS and SPEF steps, see the README.md
# in the PDK root.

set ::env(PROCESS) 55
set ::env(DEF_UNITS_PER_MICRON) 1000

if { ![info exist ::env(STD_CELL_LIBRARY)] } {
	set ::env(STD_CELL_LIBRARY) "ICsprout55_SC9T_BASIC_SVT"
}
if { ![info exist ::env(PAD_CELL_LIBRARY)] } {
	set ::env(PAD_CELL_LIBRARY) "ICsprout_55LLULP1225_IO_0901"
}

set ::env(VDD_NET) "VDD"
set ::env(GND_NET) "VSS"
set ::env(VDD_PIN) "VDD"
set ::env(GND_PIN) "VSS"

# The _ecos tech LEF of the vendor carries the wire capacitances, which
# OpenROAD uses for the parasitic estimates in place of RCX, and the Vt
# implant layers that the HVT and LVT cell LEFs reference.
set ::env(TECH_LEFS) [dict create "nom_*" "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/techlef/N551P6M_ecos.lef"]

set ::env(DEFAULT_CORNER) "nom_tt_025C_1v20"
set ::env(TIMING_VIOLATION_CORNERS) "*"
set ::env(STA_CORNERS) [list \
	"nom_tt_025C_1v20" \
	"nom_ss_125C_1v08" \
	"nom_ff_n40C_1v32" \
]

set ::env(RT_MIN_LAYER) "MET1"
set ::env(RT_MAX_LAYER) "MET4"
set ::env(IO_PIN_H_LAYER) "MET3"
set ::env(IO_PIN_V_LAYER) "MET2"
# One value per routing layer of the tech LEF (MET1 to MET5, T4M2).
set ::env(GRT_LAYER_ADJUSTMENTS) [list 0.99 0 0 0 0 0]

# There is no Magic technology for ICS55, so KLayout writes the GDS.
set ::env(PRIMARY_GDSII_STREAMOUT_TOOL) "klayout"

set ::env(KLAYOUT_TECH) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/klayout/tech/ics55.lyt"
set ::env(KLAYOUT_PROPERTIES) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/klayout/tech/ics55.lyp"
set ::env(KLAYOUT_DEF_LAYER_MAP) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/klayout/tech/ics55.map"
# Community deck, not foundry sign-off. Density and chip-edge rules only make
# sense on a full chip, so they are off for blocks.
set ::env(KLAYOUT_DRC_RUNSET) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/klayout/drc/ics55_full_mask.drc"
set ::env(KLAYOUT_DRC_DEFINES) [dict create density false chipedge false]

set scl_dir "$::env(PDK_ROOT)/$::env(PDK)/libs.ref/$::env(STD_CELL_LIBRARY)"
set io_dir "$::env(PDK_ROOT)/$::env(PDK)/libs.ref/$::env(PAD_CELL_LIBRARY)"

# The well (VNW) and substrate (VPW) pins of the cells are tied to the
# supplies, the TAPX1 cells connect them in the layout.
set ::env(SCL_POWER_PINS) [list "VDD" "VNW"]
set ::env(SCL_GROUND_PINS) [list "VSS" "VPW"]

# File base name of the library views, e.g. ICsprout55_9TSVT_basic
regexp {_([SHL]VT)$} $::env(STD_CELL_LIBRARY) -> scl_vt
set scl_base "ICsprout55_9T${scl_vt}_basic"

set ::env(CELL_LEFS) [list "$scl_dir/lef/$scl_base.lef"]
set ::env(CELL_GDS) [list "$scl_dir/gds/$scl_base.gds"]
set ::env(CELL_VERILOG_MODELS) [list "$scl_dir/verilog/$scl_base.v"]
set ::env(CELL_CDLS) [list "$scl_dir/cdl/$scl_base.cdl"]

set ::env(PAD_LEFS) [list "$io_dir/lef/IC055L_GPIO3P3V_CDG_6M.lef" "$io_dir/lef/IC055L_PAD_1P6M_5IM_T4M2.lef"]
set ::env(PAD_GDS) [list "$io_dir/gds/IC055L_GPIO3P3V_CDG_6M_0901.gds" "$io_dir/gds/IC055L_PAD_1P6M_5IM_T4M2.gds"]
# Port-only models written by the install script (the vendor models do not
# pass the Verilator lint).
set ::env(PAD_VERILOG_MODELS) "$io_dir/verilog/IC055L_GPIO3P3V_CDG_bb.v"
set ::env(PAD_CDLS) [list "$io_dir/cdl/IC055L_GPIO3P3V_CDG.cdl" "$io_dir/cdl/subckt.sp"]

# Exactly one entry must match DEFAULT_CORNER. The RC prefix (nom) only
# selects the extraction, so the keys are wildcards. The IO corners are the
# ones of the 2.5 V IO supply.
set ::env(LIB) [dict create]
dict set ::env(LIB) "*_tt_025C_1v20" "\
	$scl_dir/lib/ICsprout55_9T${scl_vt}_tt_v1p2_25c_basic_nldm.lib.gz \
	$io_dir/lib/ic055l_gpio3p3v_cdg_tt_v1p20_v2p50_25c_nldm.lib.gz"
dict set ::env(LIB) "*_ss_125C_1v08" "\
	$scl_dir/lib/ICsprout55_9T${scl_vt}_ss_v1p08_125c_basic_nldm.lib.gz \
	$io_dir/lib/ic055l_gpio3p3v_cdg_ss_v1p08_v2p25_125c_nldm.lib.gz"
dict set ::env(LIB) "*_ff_n40C_1v32" "\
	$scl_dir/lib/ICsprout55_9T${scl_vt}_ff_v1p32_-40c_basic_nldm.lib.gz \
	$io_dir/lib/ic055l_gpio3p3v_cdg_ff_v1p32_v2p75_m40c_nldm.lib.gz"

# Shared by the three libraries (same 0.2 um site and metal pitches)
set ::env(FP_TRACKS_INFO) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/librelane/tracks.info"

set ::env(PDN_MULTILAYER) 1
set ::env(PDN_RAIL_LAYER) "MET1"
set ::env(PDN_RAIL_OFFSET) 0.0
set ::env(PDN_VERTICAL_LAYER) "MET4"
set ::env(PDN_HORIZONTAL_LAYER) "MET5"
set ::env(PDN_VWIDTH) 1
set ::env(PDN_VSPACING) 1.0
set ::env(PDN_VPITCH) 16
set ::env(PDN_VOFFSET) 0.5
set ::env(PDN_HWIDTH) 1
set ::env(PDN_HSPACING) 1.0
set ::env(PDN_HPITCH) 16
set ::env(PDN_HOFFSET) 0.5
set ::env(PDN_CORE_RING) 0
set ::env(PDN_CORE_RING_VWIDTH) 3.1
set ::env(PDN_CORE_RING_HWIDTH) 3.1
set ::env(PDN_CORE_RING_VSPACING) 1.7
set ::env(PDN_CORE_RING_HSPACING) 1.7
set ::env(PDN_CORE_RING_VOFFSET) 12.45
set ::env(PDN_CORE_RING_HOFFSET) 12.45
set ::env(MACRO_BLOCKAGES_LAYER) "MET1 MET2 MET3 MET4 MET5"
