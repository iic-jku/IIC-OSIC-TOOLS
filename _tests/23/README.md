# Test 23: sak-lvs.sh smoke/regression test

`test_sak_lvs.sh` runs `sak-lvs.sh` through its full input matrix:

- Magic+Netgen (`-m`) and KLayout (`-k`) LVS on a known-good standard cell inverter in all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l)
- input variants: SPICE and CDL netlists, `.gds`/`.mag`/`.klay.gds` layouts, gzipped layouts, positional auto-derive (resolved against the current dir), multi-level `-w` work dirs, `-d` debug
- engine selection: `-b` fallback behavior, last-flag-wins
- mismatch detection: deliberately broken netlists must fail with exit 1, both for swapped terminals and for a device parameter that differs while the topology matches (Netgen property errors, Magic+Netgen in ihp-sg13g2, gf180mcuD and sky130A, KLayout in ihp-sg13g2 and sky130A)
- the Monte Carlo switch `mm_ok=1` that the IHP xschem symbols write into SPICE netlists must not fail the Magic+Netgen LVS (ihp-sg13g2, ihp-sg13cmos5l)
- sky130A KLayout LVS on a netlist as xschem writes it (subcircuit calls with W and L in micrometers)
- guard checks: every invalid combination (wrong netlist format for an engine, `.mag` for KLayout, Verilog for KLayout, unknown file formats, missing files, missing `-s/-l/-c`, unset PDK variables, unsupported PDK, missing tools, GDS top cell name mismatch) must exit with its documented error code

Set `SAK_LVS=<path>` to test a not-yet-installed version of the script.

The test reports only its verdict on the console; the per-case `[PASS]`/`[FAIL]` results and the full command output go into the log. Set `SAK_TEST_VERBOSE=1` to get every case on the console while debugging a regression.

## Test data

The data files are derived from the standard cell libraries of the installed
PDKs (`libs.ref/<stdcell-lib>/{gds,cdl,spice}`):

- `<cell>.gds`: the inverter cell extracted from the library GDS with KLayout
- `<cell>.cdl` / `<cell>.spice`: the inverter subcircuit cut out of the library netlists
- `<cell>_broken.*` (ihp-sg13g2): first device card with two terminals swapped, guaranteed LVS mismatch
- `<cell>_wide.*` (ihp-sg13g2, gf180mcuD, sky130A): the NMOS width doubled, everything else unchanged, guaranteed property error
- `<cell>_mm_ok.spice` (ihp-sg13g2, ihp-sg13cmos5l): ` mm_ok=1` appended to every device card, as the IHP xschem symbols write it
- `<cell>_xschem.cdl` / `<cell>_xschem_wide.cdl` (sky130A): the inverter written by hand in the form xschem uses for the `sky130_fd_pr` symbols (`XM0 Y A VGND VNB sky130_fd_pr__nfet_01v8 L=0.15 W=0.65 nf=1 m=1`), and the same with the NMOS width doubled
- `<cell>_wrongtop.gds` (ihp-sg13g2): top cell renamed so it does not match the file name, triggers the top cell guard
- `<cell>.mag` (ihp-sg13g2): magic-native view written by magic from the GDS
- `<cell>.klay.gds` (ihp-sg13g2): the inverter saved by KLayout with library context (the `.klay.klib` file is KLayout's library reference belonging to it). The file carries an extra `$$$CONTEXT_INFO$$$` top cell that the GDS top cell guard must tolerate. Magic logs a harmless unknown-layer complaint for the context cell and reads on.
- `dummy.v` (ihp-sg13g2): only used to exercise the KLayout-vs-Verilog guard

## Known issues

- sky130A KLayout LVS is reported as `[KNOWN]` instead of failing: the `sky130.lvs` deck reads all schematic device classes upper-case while the layout device classes are lower-case, so the compare never matches (verified with a hand-checked identical netlist). To be fixed upstream in the PDK. See issue: https://github.com/fossi-foundation/open-pdks/issues/531
