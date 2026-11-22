# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# LibreLane PDK configuration of ICS55 (digital-only), adapted from
# ckdur/icsprout55-openpdk (libs.tech/librelane/config.tcl, Apache-2.0).
#
# Differences to the port: the vendor standard cells as released (no
# regenerated layouts, no antenna or density filler cells), no RCX rules (the
# vendor publishes no extraction data), no Magic or Netgen collateral. A design
# configuration therefore has to switch off the Magic, LVS and SPEF steps, see
# the README.md in the PDK root.

set ::env(PROCESS) 55
set ::env(DEF_UNITS_PER_MICRON) 1000

if { ![info exist ::env(STD_CELL_LIBRARY)] } {
	set ::env(STD_CELL_LIBRARY) "ics55_LLSC_H7CR"
}
if { ![info exist ::env(PAD_CELL_LIBRARY)] } {
	set ::env(PAD_CELL_LIBRARY) "ICsprout_55LLULP1233_IO_251013"
}

set ::env(VDD_NET) "VDD"
set ::env(GND_NET) "VSS"
set ::env(VDD_PIN) "VDD"
set ::env(GND_PIN) "VSS"

# The _ecos tech LEF of the vendor carries the wire capacitances, which
# OpenROAD uses for the parasitic estimates in place of RCX.
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

set ::env(SCL_POWER_PINS) [list "VDD"]
set ::env(SCL_GROUND_PINS) [list "VSS"]

# The _ecos cell LEF has the signal pins on MET2 (with VIA1), which matches
# the _M2 GDS. The plain GDS has MET1 pins only, so routing to the LEF pins
# would leave every signal pin open.
set ::env(CELL_LEFS) [list "$scl_dir/lef/$::env(STD_CELL_LIBRARY)_ecos.lef"]
set ::env(CELL_GDS) [list "$scl_dir/gds/$::env(STD_CELL_LIBRARY)_M2.gds"]
set ::env(CELL_VERILOG_MODELS) [list "$scl_dir/verilog/$::env(STD_CELL_LIBRARY).v"]
set ::env(CELL_CDLS) [list "$scl_dir/cdl/$::env(STD_CELL_LIBRARY).cdl"]

set ::env(PAD_LEFS) "$io_dir/lef/ICSIOA_N55_3P3_1P6M1TM_ecos.lef"
set ::env(PAD_GDS) "$io_dir/gds/ICSIOA_N55_3P3_1P6M1TM.gds"
set ::env(PAD_VERILOG_MODELS) "$io_dir/verilog/icsIOA_N55_3P3.v"
set ::env(PAD_CDLS) "$io_dir/cdl/ICSIOA_N55_3P3.cdl"

# Exactly one entry must match DEFAULT_CORNER. The RC prefix (nom) only
# selects the extraction, so the keys are wildcards.
set ::env(LIB) [dict create]
dict set ::env(LIB) "*_tt_025C_1v20" "\
	$scl_dir/lib/$::env(STD_CELL_LIBRARY)_typ_tt_1p2_25_nldm.lib.gz \
	$io_dir/lib/ICSIOA_N55_3P3_tt_1p2_3p3_25c.lib.gz"
dict set ::env(LIB) "*_ss_125C_1v08" "\
	$scl_dir/lib/$::env(STD_CELL_LIBRARY)_ss_rcworst_1p08_125_nldm.lib.gz \
	$io_dir/lib/ICSIOA_N55_3P3_ss_1p08_2p97_125c.lib.gz"
dict set ::env(LIB) "*_ff_n40C_1v32" "\
	$scl_dir/lib/$::env(STD_CELL_LIBRARY)_ff_rcbest_1p32_m40_nldm.lib.gz \
	$io_dir/lib/ICSIOA_N55_3P3_ff_1p32_3p63_m40c.lib.gz"

set ::env(FP_TRACKS_INFO) "$::env(PDK_ROOT)/$::env(PDK)/libs.tech/librelane/$::env(STD_CELL_LIBRARY)/tracks.info"

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
