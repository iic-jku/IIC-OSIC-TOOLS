# ASAP7 in IIC-OSIC-TOOLS

ASAP7 is the 7 nm FinFET predictive PDK of Arizona State University and Arm Research (PDK version r1p7). It is meant for teaching and research. It is **not tied to a foundry and cannot be manufactured**.

Upstream: <https://github.com/The-OpenROAD-Project/asap7>. The PDK and its libraries are BSD-3-Clause licensed (`LICENSE`, `libs.ref/asap7sc7p5t/LICENSE`). The Calibre DRC, LVS and PEX decks of ASAP7 are licensed for academic use only and may not be redistributed, so they are not included. `SOURCES` lists the revision of every source.

## Licenses

Everything in this directory may be redistributed. The files keep their upstream license:

| Part | License | License file |
|---|---|---|
| Model cards, DRM, standard-cell LEF, Liberty, GDS, CDL, Verilog (ASU, `asap7_pdk_r1p7`, `asap7sc7p5t_28`) and the model libraries converted from the cards | BSD-3-Clause | `LICENSE`, `libs.ref/asap7sc7p5t/LICENSE` and `license/` |
| Files written by OpenROAD-flow-scripts: Yosys maps, `setRC.tcl`, `rcx_patterns.rules` | BSD-3-Clause | `libs.tech/librelane/common/LICENSE.orfs` |
| KLayout layer properties and DRC deck (ASAP7_for_KLayout) | BSD-2-Clause | `libs.tech/klayout/tech/LICENSE`, `libs.tech/klayout/drc/LICENSE` |
| BSIM-CMG 111.2.1 Verilog-A and the compiled `bsimcmg.osdi` (University of California, via VA-Models) | ECL-2.0 | `libs.tech/verilog-a/bsimcmg/ECL-2.0.txt`, `NOTICE` next to the OSDI objects |
| Everything else (KLayout technology and LVS deck, LibreLane and simulator setup, xschem symbols, scripts) | Apache-2.0 | SPDX headers, IIC-OSIC-TOOLS |

The ASAP7 Calibre decks are licensed for academic use only and may not be redistributed, so they are not included. The ASAP7 paper (Microelectronics Journal) is not included either.

## Contents

| Path | Content | Source |
|---|---|---|
| `libs.ref/asap7sc7p5t` | 7.5-track standard cells, RVT, LVT, SLVT and SRAM flavors: LEF (1x), tech LEF, GDS, NLDM Liberty (gzipped), CDL, Verilog | `asap7sc7p5t_28`, OpenROAD-flow-scripts platform `asap7` |
| `libs.tech/hspice` | Original BSIM-CMG 107 model cards, corners TT, FF, SS | `asap7_pdk_r1p7` |
| `libs.tech/ngspice`, `libs.tech/vacask` | Model library `models/asap7.lib` (sections `tt`, `ff`, `ss`) and BSIM-CMG 111.2.1 as `osdi/bsimcmg.osdi` | converted at install, VA-Models |
| `libs.tech/xyce` | Model library `models/asap7.lib`, built-in BSIM-CMG 107 | converted at install |
| `libs.tech/verilog-a/bsimcmg` | BSIM-CMG 111.2.1 Verilog-A source and ECL-2.0 text | VA-Models |
| `libs.tech/klayout` | Technology (`tech/asap7.lyt`, `.lyp`, DEF layer map `.map`), DRC deck `drc/asap7.lydrc`, LVS deck `lvs/asap7.lvs` | local, ASAP7_for_KLayout |
| `libs.tech/librelane` | LibreLane PDK and standard-cell configuration, example design | local, after ORFS |
| `libs.tech/xschem` | Symbols `asap7/{n,p}mos_{lvt,rvt,slvt,sram}.sym`, testbenches in `asap7_tests` | local |
| `libs.tech/pygmid` | `techsweep_asap7.py`, gm/ID lookup tables for pygmid from ngspice in the `.mat` layout of the analog-circuit-design course | local |
| `libs.doc` | Design rule manual `asap7_drm_201207a.pdf` | `asap7_pdk_r1p7` |

## Devices

All simulators use the same subcircuits: `nmos_lvt`, `nmos_rvt`, `nmos_slvt`, `nmos_sram`, `pmos_lvt`, `pmos_rvt`, `pmos_slvt` and `pmos_sram` with the terminals `d g s b` and the parameters `l` (default 20 nm, the only drawn gate length) and `nfin` (default 1). `w` is accepted for CDL compatibility and ignored. The drawn width is `nfin` times the fin pitch of 27 nm.

```spice
.lib $PDK_ROOT/asap7/libs.tech/ngspice/models/asap7.lib tt
X1 d g s b nmos_rvt l=20n nfin=3
```

Xyce runs the original cards with its built-in BSIM-CMG 107 and reproduces the per-fin Idsat of the ASAP7 paper (Clark et al., Microelectronics Journal 53, 2016, tables 3 and 4). ngspice and VACASK load BSIM-CMG 111.2.1, which drops the 107-only parameters CAPMOD, COREMOD, ETAQM, NSEG and VERSION. They agree with each other and read 2 % to 8 % lower Idsat and up to 45 % lower Ioff for LVT and SLVT devices than Xyce and the paper.

## Digital flow

Select the library with `STD_CELL_LIBRARY`: `asap7sc7p5t` (RVT, default), `asap7sc7p5t_lvt` or `asap7sc7p5t_slvt`. The ASAP7 Liberty files use ps and fF, so `CLOCK_PERIOD` and other SDC times in a LibreLane config are in ps. There is no Magic technology, so the Magic and Netgen steps are removed in the design config. `libs.tech/librelane/example` holds a complete example, its README lists the required settings and the LVS commands.

## Verification

`sak-drc.sh -k` and `sak-lvs.sh -k` run the two KLayout decks below. There is no Magic technology, so a Magic run (`-m`, the default) stops with an error, and `-b` runs KLayout only. `sak-gds-info.py -t asap7` and `sak-render.py -t asap7` know the ASAP7 layers.


* DRC: `klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/drc/asap7.lydrc -rd input=<gds> -rd topcell=<cell> -rd report=<lyrdb>`. The deck follows the DRM and is experimental. It reports violations inside some library cells (e.g. TIEHIx1, DFFASRHQNx1) and some vias of the tech LEF.
* LVS: `klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs -rd input=<gds> -rd topcell=<cell> -rd schematic=<cdl>`. FinFETs compare by `l` and `nfin` (as width), the body terminal is not compared (the cells have no well taps), and top-level pins have to match by name. Standard cells inside a design are compared at transistor level, except the cells listed in `KNOWN_MISMATCH` in the deck, whose layouts split or reorder transistor stacks against their CDL. Those are black boxes (`-rd blackbox_cells=none` compares them too and fails). Cells that match only with interchangeable inputs swapped (e.g. AO21x1 A1/A2) have these inputs declared as equivalent pins.
