# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# LibreLane PDK configuration for the ASAP7 7 nm FinFET predictive PDK.
#
# Derived from the OpenROAD-flow-scripts platform asap7 (flow/platforms/asap7,
# config.mk and openRoad/). ASAP7 is predictive and not manufacturable.
#
# Standard-cell libraries (STD_CELL_LIBRARY), one threshold flavor each:
#   asap7sc7p5t       RVT (default)
#   asap7sc7p5t_lvt   LVT
#   asap7sc7p5t_slvt  SLVT
#
# Units: the ASAP7 Liberty files use ps and fF, and LibreLane hands SDC values
# to OpenSTA unconverted, so CLOCK_PERIOD and every other time in a design
# config is in ps (as in ORFS), e.g. "CLOCK_PERIOD": 1000 for 1 GHz.
#
# Signoff: KLayout stream-out and KLayout DRC. There is no Magic technology
# for ASAP7, so a design config must switch off the Magic and Netgen steps:
#   "RUN_MAGIC_STREAMOUT": false, "RUN_MAGIC_WRITE_LEF": false,
#   "RUN_MAGIC_DRC": false, "RUN_KLAYOUT_XOR": false, "RUN_LVS": false
# LVS runs on the final GDS with the KLayout deck in libs.tech/klayout/lvs.

set pdk_dir "$::env(PDK_ROOT)/$::env(PDK)"

# Process node
set ::env(PROCESS) 7
set ::env(DEF_UNITS_PER_MICRON) 1000

set ::env(VDD_PIN) "VDD"
set ::env(GND_PIN) "VSS"
set ::env(VDD_PIN_VOLTAGE) "0.70"

set ::env(SCL_POWER_PINS) "VDD"
set ::env(SCL_GROUND_PINS) "VSS"

if { ![info exist ::env(STD_CELL_LIBRARY)] } {
    set ::env(STD_CELL_LIBRARY) asap7sc7p5t
}

# Corners of the NLDM Liberty files (nom_voltage and nom_temperature)
set ::env(STA_CORNERS) "\
    nom_tt_0p70V_25C \
    nom_ff_0p77V_0C \
    nom_ss_0p63V_100C \
"
set ::env(DEFAULT_CORNER) "nom_tt_0p70V_25C"
set ::env(TIMING_VIOLATION_CORNERS) "*"

set ::env(PRIMARY_GDSII_STREAMOUT_TOOL) "klayout"

# Technology LEF, shared by all threshold flavors
set ::env(TECH_LEFS) [dict create]
dict set ::env(TECH_LEFS) "*" "$pdk_dir/libs.ref/asap7sc7p5t/techlef/asap7_tech_1x_201209.lef"

# KLayout setup
set ::env(KLAYOUT_TECH) "$pdk_dir/libs.tech/klayout/tech/asap7.lyt"
set ::env(KLAYOUT_PROPERTIES) "$pdk_dir/libs.tech/klayout/tech/asap7.lyp"
set ::env(KLAYOUT_DEF_LAYER_MAP) "$pdk_dir/libs.tech/klayout/tech/asap7.map"

set ::env(KLAYOUT_DRC_RUNSET) "$pdk_dir/libs.tech/klayout/drc/asap7.lydrc"
set ::env(KLAYOUT_DRC_DEFINES) [dict create]

set ::env(KLAYOUT_LVS_SCRIPT) "$pdk_dir/libs.tech/klayout/lvs/asap7.lvs"
set ::env(KLAYOUT_LVS_OPTIONS) [dict create]

# Tracks (the irregular M2 tracks of ORFS are approximated by a regular grid)
set ::env(FP_TRACKS_INFO) "$pdk_dir/libs.tech/librelane/common/tracks.info"

# Tap cells every 25 um, as in ORFS
set ::env(FP_TAPCELL_DIST) 25

# OpenRCX rules from ORFS
set ::env(RCX_RULESETS) [dict create]
dict set ::env(RCX_RULESETS) "*" "$pdk_dir/libs.tech/librelane/common/rcx_patterns.rules"

# PDN as in ORFS (grid_strategy-M1-M2-M5-M6.tcl), with the followpins on M1
# only: the generic LibreLane PDN script takes one rail layer.
set ::env(PDN_RAIL_LAYER) M1
set ::env(PDN_RAIL_WIDTH) 0.018
set ::env(PDN_RAIL_OFFSET) 0

set ::env(PDN_VERTICAL_LAYER) M5
set ::env(PDN_HORIZONTAL_LAYER) M6

set ::env(PDN_VWIDTH) 0.12
set ::env(PDN_VSPACING) 0.072
set ::env(PDN_VPITCH) 5.4
set ::env(PDN_VOFFSET) 0.300

set ::env(PDN_HWIDTH) 0.288
set ::env(PDN_HSPACING) 0.096
set ::env(PDN_HPITCH) 5.4
set ::env(PDN_HOFFSET) 0.513

set ::env(PDN_CORE_RING_VWIDTH) 0.288
set ::env(PDN_CORE_RING_HWIDTH) 0.288
set ::env(PDN_CORE_RING_VSPACING) 0.096
set ::env(PDN_CORE_RING_HSPACING) 0.096
set ::env(PDN_CORE_RING_VOFFSET) 0.5
set ::env(PDN_CORE_RING_HOFFSET) 0.5

set ::env(MACRO_BLOCKAGES_LAYER) "M1 M2 M3 M4"

# Layer and via RC from ORFS setRC.tcl. LibreLane passes them to OpenROAD in
# the units of the Liberty files, which for ASAP7 are kOhm and fF, so the
# values are per um in kOhm and fF.
set ::env(LAYERS_RC) [dict create]
foreach {layer res cap} {
    M1 7.04175E-02 1e-10
    M2 2.97127E-02 1.74942E-01
    M3 3.12870E-02 1.55554E-01
    M4 1.80365E-02 1.78475E-01
    M5 1.89935E-02 1.64264E-01
    M6 1.18796E-02 1.87426E-01
    M7 1.25096E-02 1.62979E-01
    M8 8.44765E-03 1.03962E-01
    M9 8.89556E-03 9.28446E-02
} {
    dict set ::env(LAYERS_RC) "*" $layer res $res
    dict set ::env(LAYERS_RC) "*" $layer cap $cap
}

set ::env(VIAS_R) [dict create]
foreach {via res} {
    V1 1.72E-02 V2 1.72E-02 V3 1.72E-02 V4 1.18E-02 V5 1.18E-02
    V6 8.20E-03 V7 8.20E-03 V8 6.30E-03 V9 6.30E-03
} {
    dict set ::env(VIAS_R) "*" $via res $res
}

set ::env(SIGNAL_WIRE_RC_LAYERS) "M2 M3"
set ::env(CLOCK_WIRE_RC_LAYERS) "M4 M5"

# I/O pins and routing layers as in ORFS
set ::env(IO_PIN_H_LAYER) "M4"
set ::env(IO_PIN_V_LAYER) "M5"
# Pins on neighboring M4/M5 tracks give spacing and rect-only violations
# where the router lands on them
set ::env(IO_PIN_MIN_DISTANCE) 0.2

set ::env(RT_MIN_LAYER) "M2"
set ::env(RT_MAX_LAYER) "M7"
set ::env(RT_CLOCK_MIN_LAYER) "M4"

# One adjustment per routing layer M1 to M9 and Pad (ROUTING_LAYER_ADJUSTMENT)
set ::env(GRT_LAYER_ADJUSTMENTS) "0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.25"

unset pdk_dir
