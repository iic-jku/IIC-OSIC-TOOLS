# Test 23: sak-lvs.sh smoke/regression test

`test_sak_lvs.sh` runs `sak-lvs.sh` through its full input matrix:

- Magic+Netgen (`-m`) and KLayout (`-k`) LVS on a known-good standard cell inverter in all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l)
- input variants: SPICE and CDL netlists, `.gds`/`.mag`/`.klay.gds` layouts, gzipped layouts, positional auto-derive (resolved against the current dir), multi-level `-w` work dirs, `-d` debug
- xschem schematic (`inv.sch`) in every PDK with `-b`: the schematic is netlisted once per engine and both engines run. In the IHP PDKs this is the path on which the symbols write the Monte Carlo switch `mm_ok=1` into the SPICE netlist, in sky130A the path with subcircuit calls and W and L in micrometers
- Verilog netlist with a hierarchical layout of two standard cells (ihp-sg13g2), and the same layout against netlists on transistor level
- engine selection: `-b` fallback behavior, last-flag-wins
- error classes: a netlist with one deliberate error must fail with exit 1 (see below)
- verdict: every result Netgen can write after `Final result:` is judged correctly, only `Circuits match uniquely.` without property errors is a pass
- guard checks: every invalid combination (wrong netlist format for an engine, `.mag` for KLayout, Verilog for KLayout, unknown file formats, missing files, missing `-s/-l/-c`, unset PDK variables, unsupported PDK, missing tools, GDS top cell name mismatch) must exit with its documented error code
- a run without a result (unreadable GDS, netlist without the top cell) must exit with 5

Set `SAK_LVS=<path>` to test a not-yet-installed version of the script.

The test reports only its verdict on the console; the per-case `[PASS]`/`[FAIL]` results and the full command output go into the log. Set `SAK_TEST_VERBOSE=1` to get every case on the console while debugging a regression.

## Error classes

The erroneous netlists are written at runtime from the correct one (function `mutate`), so each case differs from the passing case in exactly one thing. A mutation that does not change the netlist counts as a failed case.

| kind | change | Netgen result |
|---|---|---|
| `w`, `l`, `m` | NMOS width doubled, length doubled, multiplier 2 | `Circuits match uniquely.` with `Property errors were found.` |
| `model` | NMOS of another model | `Netlists do not match.` or `Top level cell failed pin matching.` |
| `swap` | drain and gate of the NMOS swapped | `Top level cell failed pin matching.` |
| `short` | gate of the NMOS tied to its source | `Top level cell failed pin matching.` |
| `del` | PMOS removed | `Netlists do not match.` |
| `port` | a port renamed, the layout keeps the old label | `Top level cell failed pin matching.` |

For `w`, `l` and `m` the test also checks that the Netgen report shows a topology match with property errors. These are the cases a script passes if it only looks for `Circuits match uniquely`.

Magic+Netgen runs all kinds in all PDKs. A KLayout run takes 4 to 11 s (Magic+Netgen: less than 1 s), so KLayout runs all kinds in ihp-sg13g2 and `w` and `port` in the other PDKs.

The verdict cases use a stand-in for `netgen` that writes a given report, because results like `Circuits match uniquely with port errors.` or property errors in a subcell only cannot be provoked with an inverter. Magic runs for real in these cases.

## Test data

The data files are derived from the standard cell libraries of the installed
PDKs (`libs.ref/<stdcell-lib>/{gds,cdl,spice}`):

- `<cell>.gds`: the inverter cell extracted from the library GDS with KLayout
- `<cell>.cdl` / `<cell>.spice`: the inverter subcircuit cut out of the library netlists
- `<cell>_broken.*` (ihp-sg13g2): first device card with two terminals swapped, guaranteed LVS mismatch
- `<cell>_xschem.cdl` (sky130A): the inverter written by hand in the form xschem uses for the `sky130_fd_pr` symbols (`XM0 Y A VGND VNB sky130_fd_pr__nfet_01v8 L=0.15 W=0.65 nf=1 m=1`). The library CDL cannot be used for KLayout LVS, see the known issues
- `<cell>_wrongtop.gds` (ihp-sg13g2): top cell renamed so it does not match the file name, triggers the top cell guard
- `<cell>.mag` (ihp-sg13g2): magic-native view written by magic from the GDS
- `<cell>.klay.gds` (ihp-sg13g2): the inverter saved by KLayout with library context (the `.klay.klib` file is KLayout's library reference belonging to it). The file carries an extra `$$$CONTEXT_INFO$$$` top cell that the GDS top cell guard must tolerate. Magic logs a harmless unknown-layer complaint for the context cell and reads on.
- `dummy.v` (ihp-sg13g2): only used to exercise the KLayout-vs-Verilog guard
- `inv.sch` (every PDK): the inverter drawn with the device symbols of the PDK, with the device sizes of the standard cell. Written by hand in the xschem file format
- `inv.gds` (every PDK): `<cell>.gds` with the top cell renamed to `inv`. A schematic named like a standard cell would get the standard cell library appended to its netlist
- `invchain.gds` (ihp-sg13g2): two `sg13g2_inv_1` instances in series, connected with a Metal1 strap, with the pins labelled in the top cell
- `invchain.v`, `invchain.spice`, `invchain.cdl` (ihp-sg13g2): the netlists for `invchain.gds`, on standard cell level (Verilog) and on transistor level

`make_layouts.py` writes `inv.gds` and `invchain.gds` from the `<cell>.gds` files: `python3 make_layouts.py . <output dir>`.

## Known issues

- sky130A KLayout LVS is reported as `[KNOWN]` instead of failing: the `sky130.lvs` deck reads all schematic device classes upper-case while the layout device classes are lower-case, so the compare never matches (verified with a hand-checked identical netlist). To be fixed upstream in the PDK. See issue: https://github.com/fossi-foundation/open-pdks/issues/531
- KLayout LVS does not notice a renamed port in gf180mcuD and sky130A, the `port` case passes there and is reported as `[KNOWN]`. In gf180mcuD `sak-lvs.sh` runs the deck with `check_ports=false`: the deck names the substrate `SUB`, so a bulk pin such as `VPW` of an untapped standard cell can never match. Magic+Netgen reports the renamed port in all PDKs.
