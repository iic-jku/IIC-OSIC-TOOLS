# Test 25: sak-pex.sh smoke/regression test

`test_sak_pex.sh` runs `sak-pex.sh` through its full input matrix:

- PEX on a standard cell inverter in all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l)
- all PEX modes: `-m 1` (C-decoupled), `-m 2` (C-coupled, default), `-m 3` (full-RC) incl. the `-t`/`-r`/`-y` extresist overrides (verified via the netlist header)
- subcircuit handling: `-s 0` (wrapper stripped, devices preserved), `-n` (subcircuit renamed), and both combined
- input variants: `.mag`/`.gds`/`.klay.gds` layouts, gzipped layouts (created at runtime), positional auto-derive (resolved against the current dir), multi-level `-w` work dirs, `-d` debug
- netlist and cleanup checks: header present, devices/parasitics present, no `.ext`/`.tmp`/temp-dir/Tcl-script leftovers, magic log written
- guard checks: every invalid combination (out-of-range or non-integer `-m`/`-s`/`-t`/`-y`, unknown layout format, GDS top cell name mismatch, missing files, unset PDK variables, unsupported PDK, missing tools) must exit with its documented error code

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

## Notes on expected behavior

- **`-s 0`**: magic's `ext2spice subcircuits top off` option is overridden while the `ext2spice lvs` hierarchical output is active, and disabling the hierarchy changes the extracted parasitics. `sak-pex.sh` therefore strips the single `.subckt`/`.ends` wrapper pair from the finished netlist instead, so the netlist content is identical to a `-s 1` run. The test asserts both the missing wrapper and the preserved devices.
- **`-m 3` on a small cell** typically yields no R elements: the inverter nets sit below the 10 Ohm default extresist threshold. The full-RC runs therefore only assert a successful extraction and the extresist settings in the header.
