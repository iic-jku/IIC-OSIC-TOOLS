# Test 25: sak-pex.sh smoke/regression test

`test_sak_pex.sh` runs `sak-pex.sh` with both of its engines, Magic and kpex 2.5D (`-k`), through its full input matrix:

- PEX on a standard cell inverter in all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l)
- all PEX modes: `-m 1` (C-decoupled), `-m 2` (C-coupled, default), `-m 3` (full-RC) incl. the `-t`/`-r`/`-y` extresist overrides (verified via the netlist header)
- subcircuit handling: `-s 0` (wrapper stripped, devices preserved), `-n` (subcircuit renamed), and both combined
- capacitance threshold `-c`: an explicit `-c 0.01` gives the default netlist, `-c 1000` drops every capacitor of the inverter, and the value is noted in the header in `-m 2` and `-m 3`
- input variants: `.mag`/`.gds`/`.klay.gds` layouts, gzipped layouts (created at runtime), positional auto-derive (resolved against the current dir), multi-level `-w` work dirs, `-d` debug
- netlist and cleanup checks: header present, devices/parasitics present, no `.ext`/`.tmp`/temp-dir/Tcl-script leftovers, magic log written
- guard checks: every invalid combination (out-of-range or non-integer `-m`/`-s`/`-t`/`-y`, a `-c` that is no non-negative decimal number, unknown layout format, GDS top cell name mismatch, missing files, unset PDK variables, unsupported PDK, missing tools) must exit with its documented error code
- the kpex 2.5D engine (`-k`) in all four PDKs: `-m 1`, `-m 2` and `-m 3` (kpex `--mode C`, `CC` and `RC`) with the `-R` reductions, `-n` and `-s 0`, the full-RC check against a schematic (`-S`, which passes with the stdcell CDL and fails on a wrong NMOS width), the substrate tie (`-g`), `.gds.gz` and `.klay.gds` input, the run directory that only a failed run keeps, and the guards of the engine (`.mag` input, a Magic flag with `-k`, a kpex flag without it, an unknown reduction, a missing schematic, a tie net that is no port, after which kpex's netlist stays in `<cell>.pex.spice.tmp`, a tie net that is the substrate port itself, a missing cell, a PDK kpex does not know, kpex missing)

Set `SAK_PEX=<path>` to test a not-yet-installed version of the script.

The test reports only its verdict on the console; the per-case `[PASS]`/`[FAIL]` results and the full command output go into the log. Set `SAK_TEST_VERBOSE=1` to get every case on the console while debugging a regression.

## Test data

The data files are the same standard cell inverters as in tests 23/24,
extracted from the standard cell libraries of the installed PDKs
(`libs.ref/<stdcell-lib>/gds`) with KLayout:

- `<cell>.gds`: the inverter cell extracted from the library GDS
- `<cell>.mag` (ihp-sg13g2): magic-native view written by magic from the GDS
- `<cell>_wrongtop.gds` (ihp-sg13g2): top cell renamed so it does not match the file name, triggers the top cell guard
- `<cell>.klay.gds` (ihp-sg13g2): the inverter saved by KLayout with library context (the `.klay.klib` file is KLayout's library reference belonging to it). The file carries an extra `$$$CONTEXT_INFO$$$` top cell that the GDS top cell guard must tolerate, and the `.klay` marker in the file name is stripped when deriving the cell name. Magic logs a harmless unknown-layer complaint for the context cell and reads on.

The test makes two more inputs at runtime: `subtie.gds`, nine labeled Metal1 wires (eight `a_long_wire_name_<n>` and `VSS`) written with the KLayout Python module, and `wrong_w.cdl`, an inverter schematic with a 1 um wide NMOS.

## Notes on expected behavior

- **`-s 0`**: magic's `ext2spice subcircuits top off` option is overridden while the `ext2spice lvs` hierarchical output is active, and disabling the hierarchy changes the extracted parasitics. `sak-pex.sh` therefore strips the single `.subckt`/`.ends` wrapper pair from the finished netlist instead, so the netlist content is identical to a `-s 1` run. The test asserts both the missing wrapper and the preserved devices.
- **`-m 3` on a small cell** typically yields no R elements: the inverter nets sit below the 10 Ohm default extresist threshold. The full-RC runs therefore only assert a successful extraction and the extresist settings in the header.
- **kpex substrate port**: kpex's PEX-LVS puts the substrate on one global net (`sub!` in the IHP PDKs, `sky130_gnd` in sky130A, `SUB` in gf180mcuD), which is a port of the netlist unless a tap and a label name it otherwise. The ihp-sg13g2 inverter has its taps under `VSS` and no `sub!` port, so the tie is tested on `subtie.gds`, whose wires sort before `sub!` and `VSS`, so that kpex wraps the port list onto `+` lines with both on them. The gf180mcuD inverter has no tap, so `SUB` is tied to `VSS`. The sky130A inverter names its ground `VGND`, so the default `-g VSS` keeps `sky130_gnd` with a warning, and `-g VGND` ties it.
- **kpex `--check`**: kpex fails the full-RC run when its LVS netlist differs from the schematic in a device class or total, or in the top pins, after writing the netlist. `sak-pex.sh` then exits 1, writes no netlist and keeps kpex's run directory. In `-m 1` and `-m 2` kpex only warns, and `sak-pex.sh` repeats the warning on the console.
