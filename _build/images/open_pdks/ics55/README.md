# ICS55 v2 (ICsprout 55 nm, 55LLULP 1P6M), digital-only

This directory holds the ICsprout 55 nm open PDK as installed by IIC-OSIC-TOOLS, in its v2 data set (1.2 V core, 2.5 V IO, branch `main` of icsprout55-pdk). ICsprout accepts only layouts made with the v2 data from the next shuttle on. The v1 data (7-track cells, 3.3 V IO, branch `ics55-v1`) is not installed. The PDK sources and pinned revisions are listed in `SOURCES`.

## Usage restrictions

ICsprout releases this PDK as a preview. It is not fully silicon- or reliability-qualified. Use is limited to small-batch education and research tapeouts, and commercial mass production is prohibited (see <https://github.com/openecos-projects/icsprout55-pdk>).

## What is included

- Standard cells `ICsprout55_SC9T_BASIC_SVT` (default), `ICsprout55_SC9T_BASIC_HVT` and `ICsprout55_SC9T_BASIC_LVT`, 9 tracks (1.8 um rows, 0.2 um site): CDL, cell list, LEF, GDS, Verilog and NLDM Liberty in the 8 corners at 1.2 V +-10 % (compressed as `.lib.gz`). Only the typical corners `tt_v1p2_25c` and `tt_v1p2_85c` keep their power tables. In the `ss` and `ff` corners the `internal_power` and `leakage_power` groups are removed (about 75 % of each file), so power analysis works at `tt` only, timing in every corner. The vendor 0.9 V to 1.1 V corners and the CCS views are not installed. The complete files are in release `v2-2026.10.28` of icsprout55-pdk.
- GPIO library `ICsprout_55LLULP1225_IO_0901` (`IC055L_GPIO3P3V_CDG`) with Liberty for 2.5 V and 3.3 V IO supply, and the bond pads `IC055L_PAD_1P6M_5IM_T4M2`. LibreLane reads a port-only copy of its Verilog (`verilog/IC055L_GPIO3P3V_CDG_bb.v`).
- Tech LEF (`libs.tech/techlef`) and the vendor layer map (`libs.tech/icsprout55.layermap`).
- LibreLane configuration (`libs.tech/librelane`), written for this image. It agrees with the 9-track configuration of <https://github.com/ckdur/icsprout55-openpdk>.
- KLayout technology `ics55` (`libs.tech/klayout/tech`).
- KLayout DRC (`libs.tech/klayout/drc`) from <https://github.com/Ayoubbelguellaoui/ics55_klayout_drc>.
- KLayout LVS (`libs.tech/klayout/lvs/ics55.lvs`), digital-only.

## What is missing

- **No sign-off.** The KLayout DRC is a community deck and the KLayout LVS was written for this image. Neither is a foundry deck.
- **No SPICE models.** ICsprout does not publish them (<https://github.com/openecos-projects/icsprout55-pdk/issues/1>), so there is no analog flow and no ngspice or xschem setup.
- **No RC extraction rules.** OpenROAD estimates parasitics from the wire capacitances of the tech LEF.
- **No Magic or Netgen setup.**
- No SRAM or ROM macros and no PLL (upstream generates them with the ECOS compilers).
- No decap cells in LibreLane: placed next to other cells, the internal node of `FILLCAP*` connects to the neighbour and LVS fails. Each `FILLCAP` matches on its own.

## KLayout LVS

The deck compares the 1.2 V core MOS devices (SVT, HVT, LVT, native) against a CDL or SPICE netlist. Other device types are not extracted, among them the 2.5 V devices of the GPIO library, so a design using them fails LVS and IO pads have to be black boxes. MOS devices are compared as three-terminal devices, so well and substrate ties are not checked. Split gates (a stack built as two parallel half-width stacks) are reduced before the compare.

The netlist has to contain the standard cells. All 719 cells of each of the three libraries match their vendor CDL in `libs.ref/*/cdl`.

```bash
cat design.cdl $PDKPATH/libs.ref/ICsprout55_SC9T_BASIC_SVT/cdl/ICsprout55_9TSVT_basic.cdl > design_full.cdl
klayout -b -r $PDKPATH/libs.tech/klayout/lvs/ics55.lvs -rd input=design.gds -rd schematic=design_full.cdl -rd topcell=design
```

`sak-lvs -k -s design_full.cdl -l design.gds -c design` runs the same deck. OpenROAD writes the CDL of a LibreLane result with `write_cdl -masters <cell CDL> design.cdl` after `read_db final/odb/design.odb`.

## KLayout DRC

```bash
klayout -b -r $PDKPATH/libs.tech/klayout/drc/ics55_full_mask.drc -rd input=design.gds -rd top=design -rd report=drc.lyrdb
```

`sak-drc -k` runs the same deck. `-rd density=false -rd chipedge=false` turns off the full-chip rules for a block.

The deck reports violations on a routed LibreLane block. Most of them are the via enclosure rules `VIA1.EN.2` to `VIA3.EN.2`, which the deck checks on all four sides, while the vendor Calibre rule asks for the enclosure on two opposite sides only. The standard cells themselves add `NP.EN.3` and others.

## LibreLane

Select the PDK with `sak-pdk ics55` (standard cells `ICsprout55_SC9T_BASIC_SVT`, or pass another one as the second argument) and run LibreLane with `--manual-pdk`. The design configuration has to remove the steps that need Magic, Netgen or extracted parasitics, and replace the post-route STA by the one on estimated parasitics:

```json
{
    "ERROR_ON_KLAYOUT_DRC": false,
    "meta": {
        "version": 2,
        "flow": "Classic",
        "substituting_steps": {
            "Magic.StreamOut": null,
            "Magic.WriteLEF": null,
            "Magic.DRC": null,
            "Checker.MagicDRC": null,
            "KLayout.XOR": null,
            "Checker.XOR": null,
            "Magic.SpiceExtraction": null,
            "Checker.IllegalOverlap": null,
            "Netgen.LVS": null,
            "Checker.LVS": null,
            "OpenROAD.RCX": null,
            "OpenROAD.STAPostPNR": "OpenROAD.STAMidPNR",
            "OpenROAD.IRDropReport": null,
            "Odb.CheckDesignAntennaProperties": null
        }
    }
}
```

The hold repair buffers short flop-to-flop paths, so a small block may need a lower `FP_CORE_UTIL` (test 59 uses 35) to leave room for them. KLayout LVS of the result is a separate step, see above. The block flow is tested (regression test 59 of IIC-OSIC-TOOLS), the chip flow with the IO library is not.
