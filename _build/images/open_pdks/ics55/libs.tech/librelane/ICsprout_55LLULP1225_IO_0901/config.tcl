# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Pad ring of the ICS55 v2 GPIO library ICsprout_55LLULP1225_IO_0901 for the
# LibreLane Chip flow. Sites, corner and fillers are taken from the vendor LEF
# IC055L_GPIO3P3V_CDG_6M.lef. The Chip flow with this library is not tested.

set ::env(PAD_SITE_NAME) "IOSite"
set ::env(PAD_CORNER_SITE_NAME) "CornerSite"
set ::env(PAD_CORNER) "PCORNER"
set ::env(PAD_FILLERS) [list PFILL10 PFILL5 PFILL2 PFILL1 PFILL01 PFILL001 PFILL0005 PFILL0001]

# The bond pads are separate cells (IC055L_PAD_1P6M_5IM_T4M2.lef), which the
# flow does not place.
set ::env(PAD_BONDPAD_NAME) ""

set ::env(PAD_PLACE_IO_TERMINALS) [list PDBSDU/PAD PDISDU/PAD PANA2/PAD PANA2C/PAD PANA2I/PAD]
set ::env(PAD_EDGE_SPACING) 0
