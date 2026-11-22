# ICS55 (ICsprout 55 nm, 55LLULP 1P6M), digital-only

This directory holds the ICsprout 55 nm open PDK as installed by IIC-OSIC-TOOLS. The PDK sources and pinned revisions are listed in `SOURCES`.

## Usage restrictions

ICsprout releases this PDK as a preview. It is not fully silicon- or reliability-qualified. Use is limited to small-batch education and research tapeouts, and commercial mass production is prohibited (see <https://github.com/openecos-projects/icsprout55-pdk>).

## What is included

- Standard cells `ics55_LLSC_H7CR` (RVT, default), `ics55_LLSC_H7CH` (HVT) and `ics55_LLSC_H7CL` (LVT), v1.10, 7 tracks: CDL, cell list, LEF, GDS, Verilog and NLDM Liberty in 7 corners (compressed as `.lib.gz`).
- IO library `ICsprout_55LLULP1233_IO_251013`.
- Tech LEF (`libs.tech/techlef`) and the vendor layer map (`libs.tech/icsprout55.layermap`).
- LibreLane configuration (`libs.tech/librelane`), based on <https://github.com/ckdur/icsprout55-openpdk>.
- KLayout technology `ics55` (`libs.tech/klayout/tech`).
- KLayout DRC (`libs.tech/klayout/drc`) from <https://github.com/Ayoubbelguellaoui/ics55_klayout_drc>.
- KLayout LVS (`libs.tech/klayout/lvs/ics55.lvs`), digital-only.

## What is missing

- **No sign-off.** The KLayout DRC is a community deck and the KLayout LVS was written for this image. Neither is a foundry deck.
- **No SPICE models.** ICsprout does not publish them (<https://github.com/openecos-projects/icsprout55-pdk/issues/1>), so there is no analog flow and no ngspice or xschem setup.
- **No RC extraction rules.** OpenROAD estimates parasitics from the wire capacitances of the tech LEF.
- **No Magic or Netgen setup.**
- No SRAM macros and no PLL.

## KLayout LVS

The deck compares the 1.2 V core MOS devices (SVT, HVT, LVT, native) and the 3.3 V IO MOS devices against a CDL or SPICE netlist. Other device types are not extracted, so a design using them fails LVS. MOS devices are compared as three-terminal devices, so well and substrate ties are not checked. Split gates (a stack built as two parallel half-width stacks) are reduced before the compare.

The netlist has to contain the standard cells. The CDLs in `libs.ref/*/cdl` are converted from the vendor ones so that KLayout reads them (helper subcircuits defined once, parameters declared). 777 of the 785 cells of each library match their layout. The 8 that do not are in the exclude lists of the LibreLane configuration.

```bash
cat design.cdl $PDKPATH/libs.ref/$STD_CELL_LIBRARY/cdl/$STD_CELL_LIBRARY.cdl > design_full.cdl
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

Select the PDK with `sak-pdk ics55` (standard cells `ics55_LLSC_H7CR`, or pass another one as the second argument) and run LibreLane with `--manual-pdk`. The design configuration has to remove the steps that need Magic, Netgen or extracted parasitics, and replace the post-route STA by the one on estimated parasitics:

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

KLayout LVS of the result is a separate step, see above. The block flow is tested (regression test 59 of IIC-OSIC-TOOLS), the chip flow with the IO library is not.
