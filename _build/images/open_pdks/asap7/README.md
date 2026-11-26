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
| BSIM-CMG 107.0.0 Verilog-A and the compiled `bsimcmg.osdi` (University of California, via CMC.jl) | BSIM license of the University of California: free redistribution and modification, no charge for the code itself, acknowledgment of the University of California | header of `libs.tech/verilog-a/bsimcmg/bsimcmg_main.va`, `LICENSE.CMC.jl`, `NOTICE` next to the OSDI objects |
| Everything else (KLayout technology and LVS deck, LibreLane and simulator setup, xschem symbols, scripts) | Apache-2.0 | SPDX headers, IIC-OSIC-TOOLS |

The ASAP7 Calibre decks are licensed for academic use only and may not be redistributed, so they are not included. The ASAP7 paper (Microelectronics Journal) is not included either.

## Contents

| Path | Content | Source |
|---|---|---|
| `libs.ref/asap7sc7p5t` | 7.5-track standard cells, RVT, LVT, SLVT and SRAM flavors: LEF (1x), tech LEF, GDS, NLDM Liberty (gzipped), CDL, Verilog | `asap7sc7p5t_28`, OpenROAD-flow-scripts platform `asap7` |
| `libs.tech/hspice` | Original BSIM-CMG 107 model cards, corners TT, FF, SS | `asap7_pdk_r1p7` |
| `libs.tech/ngspice`, `libs.tech/vacask` | Model library `models/asap7.lib` (sections `tt`, `ff`, `ss`) and BSIM-CMG 107.0.0 as `osdi/bsimcmg.osdi` | converted at install, CMC.jl |
| `libs.tech/xyce` | Model library `models/asap7.lib`, built-in BSIM-CMG 107 | converted at install |
| `libs.tech/verilog-a/bsimcmg` | BSIM-CMG 107.0.0 Verilog-A source as compiled (patched by `fix_bsimcmg107_va.py`) | CMC.jl |
| `libs.tech/klayout` | Technology (`tech/asap7.lyt`, `.lyp`, DEF layer map `.map`), DRC deck `drc/asap7.lydrc`, LVS deck `lvs/asap7.lvs`, passive device parameters `tech/asap7_passives.json`, PCell library `python/asap7_pcells.py` (registered by `pymacros/asap7_pcells.lym`), layout generator `python/asap7_layout.py`, routed example `python/asap7_example.py` | local, ASAP7_for_KLayout |
| `libs.tech/librelane` | LibreLane PDK and standard-cell configuration, example design | local, after ORFS |
| `libs.tech/xschem` | Symbols `asap7/{n,p}mos_{lvt,rvt,slvt,sram}.sym`, `{n,p}mos18_rvt.sym`, `ndio.sym`, `pdio.sym`, `pnp.sym`, `{n,p}cap_{lvt,rvt,slvt,sram}.sym`, `rm.sym`, `rtfr.sym`, `cmom.sym`, testbenches in `asap7_tests` | local |
| `libs.tech/pygmid` | `techsweep_asap7.py`, gm/ID lookup tables for pygmid from ngspice in the `.mat` layout of the analog-circuit-design course | local |
| `libs.doc` | Design rule manual `asap7_drm_201207a.pdf` | `asap7_pdk_r1p7` |

## Devices

All simulators use the same subcircuits: `nmos_lvt`, `nmos_rvt`, `nmos_slvt`, `nmos_sram`, `pmos_lvt`, `pmos_rvt`, `pmos_slvt` and `pmos_sram` with the terminals `d g s b` and the parameters `l` (default 20 nm, the only drawn gate length), `nfin` (default 1) and the multiplier `m`. `w` is accepted for CDL compatibility and ignored. The drawn width is `nfin` times the fin pitch of 27 nm.

`mm=1` on an instance adds threshold mismatch: σ(Vth) = 1.4 mV µm / √(gate area), the gate area being `nfin` · `m` · 70.5 nm · `l` (fin height 32 nm, fin thickness 6.5 nm), which is 21 mV for 3 fins. ASAP7 has no variability data. 1.4 mV µm is the n-FinFET value of a 14 nm SOI process (IEDM 2013, 0.7 mV µm for p-FinFETs there) and is used for both polarities, so this is an assumption. ngspice draws a new value per instance in every run, Xyce and VACASK give the nominal device unless their sampling is set up.

### Gate lengths

ASAP7 draws every gate at 20 nm, and the model cards are fitted at that length only. IIC-OSIC-TOOLS allows more lengths for analog design: **20, 24, 28, 36, 60 and 80 nm** for the core FinFETs, at the gate spacing of ASAP7 (34 nm, so the gate pitch is `l` + 34 nm). Only 20 nm is ASAP7.

* No gate-length list of a 7 nm process is published, so the set is a guess from two Intel papers, scaled to the 54 nm gate pitch of ASAP7. The 22 nm SoC process has logic gates of 30, 34 and 40 nm (Jan et al., IEDM 2012, table 1), which gives 24 and 28 nm. 22FFL has long-channel analog FinFETs of 74, 120 and 160 nm on gate pitches of 144, 216 and 270 nm next to logic on 108 nm (Sell et al., IEDM 2017, as reported by [Real World Tech](https://www.realworldtech.com/intel-22ffl-process/3/)), which gives 36, 60 and 80 nm.
* The models at other lengths are an extrapolation by BSIM-CMG. The cards keep channel length modulation (`PCLM`) and the drain-induced barrier lowering of the output resistance (`PDIBL2`) constant, so the intrinsic gain would stop rising beyond about 50 nm. Both are moved to the 1/Leff binning term of the model, scaled so that the 20 nm device is unchanged. The gain of `nmos_rvt` at VGS = VDS = 0.35 V is then 54, 132 and 306 at 20, 36 and 80 nm. This is an assumption, not a fit.
* The DRC rule `GATE.W.1` accepts the lengths of the set, the LVS deck extracts and compares the length.

### IO FinFETs

ASAP7 has core devices for 0.7 V only and no IO library. `nmos18_rvt` and `pmos18_rvt` are 1.8 V FinFETs with a thick gate oxide, **added by IIC-OSIC-TOOLS**: same terminals and parameters as the core devices, `l` of **80 (default), 160 or 240 nm**, a gate spacing of 100 nm, and the new layer `TG` (GDS 123/0) over the device.

* The targets are the 1.8 V thick-gate transistors of the Intel 22 nm SoC process (Jan et al., IEDM 2012, table 1): 80 nm minimum gate length on a 180 nm gate pitch, 0.92 and 0.80 mA/µm at 1.8 V and 10 pA/µm off current. The models give 0.91 and 0.81 mA/µm (per µm of fin perimeter, 70.5 nm per fin) at about 10 pA/µm, with a threshold of 0.45 V.
* The cards are the RVT cards with a 3.2 nm oxide (`eot`, `toxp`, `toxg`), the work function shifted by 0.15 V, `ptwg` set to 0 (the core fit of the saturation current at 0.7 V cuts the current at 1.8 V to a sixth) and a smaller gate-induced drain leakage. They are not fitted to silicon of a 7 nm process.
* 160 nm is the longest 22FFL gate, 240 nm stays below the longest published FinFET gate found (280 nm, the 3.3 V minimum of the 22 nm process). The gain of `nmos18_rvt` at VGS = VDS = 0.9 V is 34, 60 and 86 at 80, 160 and 240 nm, the PMOS reaches 16 to 28.
* There are no IO cells. A plain pad plate is among the PCells.

### Junction diodes and vertical PNP

ASAP7 has no diode and no bipolar transistor. `ndio`, `pdio` and `pnp` are **added by IIC-OSIC-TOOLS** with assumed parameters: the contacted active area of a tap cell with the implant of a source or drain, under the marker `DIODE` (GDS 124/0) or `BJT` (GDS 125/0).

| Device | Terminals | Junction |
|---|---|---|
| `ndio` | `a k` | n+ active in the substrate, `a` is the substrate |
| `pdio` | `a k` | p+ active in the well, `k` is the well |
| `pnp` | `c b e` | vertical PNP: emitter p+ in the well, base the well, collector the substrate |

* The parameters are `nfin` (fins per strip) and `m` (strips). The area is the drawn active area, 16 nm by `nfin` · 27 nm per strip.
* Assumed values, no data of a 7 nm junction was found: saturation current 1e-19 A/µm² (0.72 V forward voltage at 58 nA/µm², -1.6 mV/K), emission coefficient 1.03, series resistance 5 Ω µm², 2 fF/µm² junction capacitance, and a current gain of 1.5 for the PNP (the vertical PNP of a FinFET process has a gain near 1). The corners scale the saturation current by 2 (`ff`) and 0.5 (`ss`).
* The PNP is the device a bandgap reference uses: the emitter voltage of 1 strip minus that of 8 strips at the same current is 55.4 mV at 27 °C.
* `ndio` to the ground rail and `pdio` to the supply rail are the usual ESD diodes of a pin. No ESD rating is modeled (no breakdown, no high-current behavior).

```spice
.lib $PDK_ROOT/asap7/libs.tech/ngspice/models/asap7.lib tt
X1 d g s b nmos_rvt l=20n nfin=3
```

Xyce runs the original cards with its built-in BSIM-CMG 107 and reproduces the per-fin Idsat of the ASAP7 paper (Clark et al., Microelectronics Journal 53, 2016, tables 3 and 4). ngspice and VACASK load the same BSIM-CMG 107.0.0, compiled with OpenVAF, and run the same cards. They match Xyce within 0.5 % on Idsat and 2 % on Ioff. The Verilog-A source gets three edits before compiling (`fix_bsimcmg107_va.py`), none of which changes the currents or charges: the geometry parameters (`l`, `nfin`, ...) become instance parameters, the lower bound of EOTACC accepts the `eotacc = 1e-10` of the cards, and the operating-point outputs (`gm`, `gds`, `cgg`, ...) that the source has commented out are switched on.

## Passive devices

ASAP7 defines FinFETs only: no resistor, capacitor or diode has a model, a layer or a design rule. The devices below are **an addition of IIC-OSIC-TOOLS for analog design and not part of ASAP7**. `scripts/asap7_passives.py` of the image build holds every number and the reasoning, `libs.tech/klayout/tech/asap7_passives.json` is the copy that the models, the LVS deck and the layout generator share.

| Device | Terminals | Parameters | Value |
|---|---|---|---|
| `rm1` ... `rm9` | `p n` | `w`, `l`, `m` | Metal resistor on M1 ... M9, R = Rsh · l / w |
| `rtfr` | `p n b` | `w`, `l`, `m`, `mm` | TiN thin-film resistor, R = (600 Ω · l + 30 Ω µm) / w |
| `cmom_m<bot>m<top>` | `p n` | `w`, `l`, `m` | Woven MOM capacitor on M`bot` to M`top`, `bot` 1 to 6, `top` up to 7 |
| `{n,p}mos_*` as capacitor | `g b` (symbol) | `nfin`, `l`, `m` | FinFET with source, drain and body tied, symbols `ncap_*` and `pcap_*` |

```spice
.lib $PDK_ROOT/asap7/libs.tech/ngspice/models/asap7.lib tt
X1 a b rm2 w=18n l=1.8u
X2 a b vss rtfr w=108n l=1u
X3 a b cmom_m4m7 w=1u l=2u
```

**Metal resistors.** A wire under the marker layer `RES_M<n>` (GDS 120/`n`). The sheet resistance is the wire resistance of the OpenRCX rules of OpenROAD-flow-scripts (`librelane/common/rcx_patterns.rules`) times the minimum width, so a resistor reads what the digital flow extracts for the same wire: 0.56, 0.53, 0.56, 0.43, 0.46, 0.38, 0.40, 0.34 and 0.36 Ω/sq for M1 to M9. These values hold for minimum-width wires and are used for every width. TC1 is 3.0e-3/K for all layers: Matthiessen's rule scales the 3.9e-3/K of bulk copper by the ratio of bulk to wire resistivity (1.68 to about 2.2 µΩ cm). TC2 is 0, the resistivity of copper is linear from 290 K to 425 K (Schuster, Vangel and Schafft, Microelectronics Reliability 41, 2001). Metal resistors are low-ohmic: 1 kΩ takes 34 µm of minimum-width M2.

**Thin-film resistor.** An assumed device. Foundry 16 nm and 7 nm FinFET processes list a TiN high-resistance resistor ([Europractice on TSMC](https://europractice-ic.com/technologies/asics/tsmc/)), placed in the dielectric above the gates and contacted by vias. Here it is a film on the new layer `TFR` (GDS 121/0) below M1, each end contacted by a V0 bar under an M1 strip. `l` is the distance between the two M1 strips. No measured data of such a resistor in a FinFET process was found, so the parameters are set from published TiN films and are not validated:

| Parameter | Value | Basis |
|---|---|---|
| Sheet resistance | 600 Ω/sq | TiN films of 420 Ω/sq at 50 nm and 550 Ω/sq ([US20040241951A1](https://patents.google.com/patent/US20040241951A1/en)) |
| End resistance | 15 Ω µm per end | assumed |
| TC1, TC2 | -300 ppm/K, 0.5 ppm/K² | reported between -650 ppm/K (thin) and +750 ppm/K (thick), a thin film is taken as weakly negative |
| Capacitance to `b` | 0.19 fF/µm² and 0.036 fF/µm of edge, half on each end | 180 nm of SiO2 to the silicon, fringe after Sakurai and Tamaru (IEEE TED 30, 1983) |
| Mismatch (`mm=1`) | σ(ΔR/R) = 2 % µm / √(w · l · m) | area law, polysilicon resistors are quoted with about 3 % µm ([Boser, EE240B](https://www2-bsac.eecs.berkeley.edu/~boser/courses/240B/lectures/M13%20Matching.pdf)) |
| Minimum `w`, `l` | 54 nm, 108 nm | assumed, like the design rules `TFR.*` |

A resistor of 108 nm by 1 µm has 5.83 kΩ, 0.1 fF to the substrate and a mismatch σ of 6.1 %. The mismatch term draws one `agauss` value per instance. ngspice draws it in every run with `mm=1`, Xyce and VACASK give the nominal value unless their sampling is set up.

**MOM capacitor.** Minimum-width fingers at minimum spacing inside the marker `MOMCAP` (GDS 122/0), in the preferred direction of each layer (M1 vertical, M2 horizontal, and so on), alternately on the plates `p` and `n`. Fingers of neighboring layers cross, and vias at the first and the last finger tie the layers together. Only the coupling between neighboring fingers of one layer counts: 0.047 to 0.048 fF/µm per finger pair on M1 to M3 and 0.056 fF/µm on M4 to M7, half of the two-neighbor coupling of the OpenRCX rules at minimum spacing. A large `cmom_m4m7` reaches 4.1 fF/µm², `cmom_m1m7` 8.0 fF/µm². The capacitance between the layers and to the substrate is not modeled.

**MOS capacitors.** The symbols `ncap_*` and `pcap_*` place a FinFET with source, drain and body on one pin. Nothing is added to the models. A device has the single gate length of 20 nm, so a useful capacitor needs many of them: `nfin=4 m=10` of `nmos_rvt` reads 2.6 fF at 0.7 V.

**Corners.** No data exists, the sections scale the typical values: resistors by 0.85 (`ff`) and 1.15 (`ss`), capacitors by 0.90 and 1.10. Resistances are given at 27 °C.

## Layout of the devices

Every device with a model has a PCell in the KLayout library `ASAP7`, which KLayout loads for layouts of the technology `asap7` (`sak-pdk asap7` puts the technology directory into `KLAYOUT_PATH`). All of them pass the LVS deck, and the DRC deck apart from the tap rule noted below.

| PCell | Device | Parameters |
|---|---|---|
| `nmos`, `pmos` | `{n,p}mos_{lvt,rvt,slvt,sram}`, `{n,p}mos18_rvt` | `vt`, `l`, `nfin`, `nf` (fingers, the `m` of the model), `strap` |
| `ncap`, `pcap` | MOS capacitor (`ncap_*`, `pcap_*` symbols) | `vt`, `l`, `nfin`, `nf` |
| `ptap`, `ntap` | substrate contact for NMOS rows, well contact for PMOS rows | `nfin` |
| `ndio`, `pdio`, `pnp` | junction diodes and vertical PNP, drawn with their body taps | `nfin`, `m` |
| `rm` | `rm1` ... `rm9` | `n` (metal level), `w`, `l` |
| `rtfr` | `rtfr` | `w`, `l` |
| `cmom` | `cmom_m<bot>m<top>` | `bot`, `top`, `w`, `l` |
| `pad` | pad plate (no model, extracted as capacitance) | `w`, `l` |

* A FinFET is one transistor row of a standard cell: `nf` gates between two dummy gates, at the 54 nm gate pitch for `l` = 20 nm, `nfin` fins, a contacted M1 strip on every source and drain, and all gates tied on M1 above the active area (pin `G`). `strap` ties the sources and the drains on two M2 bars (pins `S` and `D`). `ncap` and `pcap` tie all of them to one bar (pin `B`).
* A FinFET on its own violates `ACTIVE.LUP.1` (no body contact within 30 µm), like a standard cell without a tap cell. Abut `ptap` (next to NMOS) or `ntap` (next to PMOS) with the same `nfin`, the rows have the same height. With `-rd body=true` the LVS deck compares the body: the substrate net of the `ptap` for NMOS, the well net of the `ntap` for PMOS.
* `l` is one of the gate lengths above, 20 nm by default. `vt` = `18` draws the IO FinFET with the layer `TG`.

`libs.tech/klayout/python/asap7_layout.py` writes the same cells from the command line:

```bash
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py mos --type n --vt rvt --nfin 3 --nf 2 --strap -o nmos.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py mos --type n --nfin 3 --tap -o ptap.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py mos --type p --vt 18 --lg 160 --nfin 4 --nf 2 -o pmos18_rvt.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py pnp --nfin 4 -m 8 -o pnp.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py rm -n 2 -w 0.018 -l 1.8 -o rm2.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py rtfr -w 0.108 -l 1 -o rtfr.gds
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_layout.py cmom --bot 4 --top 7 -w 1 -l 2 -o cmom.gds
```

## Example and parasitic extraction

`libs.tech/klayout/python/asap7_example.py` writes a routed example, a common-source amplifier with `nmos_rvt`, its substrate tap, `rtfr` as load and `cmom_m2m3` at the output (`cs_amp.gds` and its netlist `cs_amp.cdl`). It is DRC clean and matches its netlist:

```bash
python3 $PDK_ROOT/asap7/libs.tech/klayout/python/asap7_example.py .
klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/drc/asap7.lydrc -rd input=cs_amp.gds -rd topcell=cs_amp -rd report=cs_amp.lyrdb
klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs -rd input=cs_amp.gds -rd topcell=cs_amp -rd schematic=cs_amp.cdl -rd body=true -rd pex=cs_amp.pex.spice
```

`-rd pex=<file>` of the LVS deck writes a netlist for simulation: the extracted devices as calls of the PDK models, plus the capacitance of the metal wires between the nets and to the substrate (extra pin `VSUB`, and `VWELL` for the PMOS bodies without `body=true`). Tie `VSUB` to the substrate potential in the testbench.

* Between wires of one layer and from a wire to the substrate, the values are the ones of the OpenRCX rules of the digital flow (coupling over distance, and the capacitance of a wire without neighbors). 10 µm of two M2 wires at minimum spacing give 0.48 fF between them and 0.38 fF each to the substrate.
* For wide wires and between two neighboring layers a parallel plate is added. ASAP7 publishes no layer stack, so it is assumed: a metal is twice as thick as its minimum width (the 2:1 aspect ratio of the ASAP7 paper), the dielectric to the next metal is as thick as the metal, M1 starts 150 nm above the substrate, and the relative permittivity is 2.7.
* `-rd pex_res=true` adds the resistance of the metal wires and vias with KLayout's resistance extractor: a net becomes a resistor network between its pin (the label) and the contacts of its devices (V0 for devices below M1, the metal next to `rm` and `cmom`). The sheet resistances are the ones of the metal resistors, the via resistances the ones of ORFS `setRC.tcl` (17.2 Ω for V1 down to 6.3 Ω for V8, V0 taken as V1). The contacts of one device terminal count as one point, and the wire capacitances stay on the node of the pin. 9.9 µm of minimum-width M2 read 294 Ω.
* A `pad` plate adds a parallel-plate capacitance to the substrate (15 fF for 20 µm by 20 µm).
* Not extracted: anything below M1 (LIG, LISD, gate), and the fingers inside a `MOMCAP` marker, which `cmom` models. Wires are not shielded by a third net in between, and all capacitance to the substrate is counted for every layer, so the result is on the high side.
* The layout is flattened for this, so it is meant for analog cells, not for a digital block.

## Limits for analog design

* The parasitic extraction uses an assumed layer stack (see above). The Calibre decks are not included, and there is no Magic technology.
* The passive devices, the junction devices, the IO FinFETs, the gate lengths other than 20 nm, the mismatch terms and the corner factors are assumptions without silicon data, as listed above.
* The extracted wire resistance is lumped per device terminal and not distributed with the capacitance, and resistance below M1 is left out.
* The `pad` is a plate on the layer Pad over M9 stripes (ASAP7 limits M9 to 2 µm width). ASAP7 has no rule for a bond pad, a bump or a passivation opening, so it is a probe and connection plate, not a qualified bond pad. There are no IO cells with ESD protection.
* No inductor model, and the only varactor is the MOS capacitor.
* Without `-rd body=true` the LVS deck does not compare the body of a FinFET or the substrate terminal of `rtfr`. With it, a FinFET without a tap still matches a schematic whose body net is a pin without other devices.

## Digital flow

Select the library with `STD_CELL_LIBRARY`: `asap7sc7p5t` (RVT, default), `asap7sc7p5t_lvt` or `asap7sc7p5t_slvt`. The ASAP7 Liberty files use ps and fF, so `CLOCK_PERIOD` and other SDC times in a LibreLane config are in ps. There is no Magic technology, so the Magic and Netgen steps are removed in the design config. `libs.tech/librelane/example` holds a complete example, its README lists the required settings and the LVS commands.

## Verification

`sak-drc.sh -k` and `sak-lvs.sh -k` run the two KLayout decks below. There is no Magic technology, so a Magic run (`-m`, the default) stops with an error, and `-b` runs KLayout only. `sak-gds-info.py -t asap7` and `sak-render.py -t asap7` know the ASAP7 layers.


* DRC: `klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/drc/asap7.lydrc -rd input=<gds> -rd topcell=<cell> -rd report=<lyrdb>`. The deck follows the DRM and is experimental. It reports violations inside some library cells (e.g. TIEHIx1, DFFASRHQNx1) and some vias of the tech LEF. The rules `RES.*`, `TFR.*` and `MOM.*` of the passive devices `TG.*` of the IO FinFETs and `DIODE.*` and `BJT.*` of the junction devices are local assumptions and not in the DRM, and `GATE.W.1` accepts the gate lengths listed above instead of 20 nm only.
* LVS: `klayout -b -r $PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs -rd input=<gds> -rd topcell=<cell> -rd schematic=<cdl>`. FinFETs compare by `l` and `nfin` (as width), the body terminal is not compared (the cells have no well taps), and top-level pins have to match by name. Standard cells inside a design are compared at transistor level, except the cells listed in `KNOWN_MISMATCH` in the deck, whose layouts split or reorder transistor stacks against their CDL. Those are black boxes (`-rd blackbox_cells=none` compares them too and fails). Cells that match only with interchangeable inputs swapped (e.g. AO21x1 A1/A2) have these inputs declared as equivalent pins. Passive devices compare by value: `rm<n>` and `rtfr` by R, and every pair of neighboring fingers in a `MOMCAP` marker is a capacitor between the nets of the two fingers, summed per net pair and compared by C, so a finger on the wrong net does not match. The substrate terminal of `rtfr` is not compared.
