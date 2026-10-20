# Test 24: sak-drc.sh smoke/regression test

`test_sak_drc.sh` runs `sak-drc.sh` through its full input matrix:

- Magic (`-m`) and KLayout (`-k`) DRC on a standard cell inverter in all supported PDKs (sky130A, gf180mcuD, ihp-sg13g2, ihp-sg13cmos5l)
- input variants: `.gds`/`.mag`/`.klay.gds` layouts, gzipped layouts, positional auto-derive (resolved against the current dir), multi-level `-w` work dirs, `-c` clean, `-f` flatglob, `-d` debug
- engine selection: `-b`, last-flag-wins, `-b` fallback to Magic for a `.mag` layout
- all three `-l` DRC levels (`precheck`/`macro`/`regular`) incl. asserting which per-level reports are (not) produced
- the KLayout process limit `-j`: `-j 1` runs the four ihp `regular` parts one after another and each part writes its own report, `-j 8` splits the ihp rule deck into one process per rule table, and the gf180mcuD and sky130A verdicts stay the same under `-j 1`
- guard checks: every invalid combination (unknown layout format, unknown DRC level, invalid `-j` value, `.mag` for KLayout, GDS top cell name mismatch, missing files, unset PDK variables, unsupported PDK, missing tools) must exit with its documented error code

Set `SAK_DRC=<path>` to test a not-yet-installed version of the script.

The test reports only its verdict on the console; the per-case `[PASS]`/`[FAIL]` results and the full command output go into the log. Set `SAK_TEST_VERBOSE=1` to get every case on the console while debugging a regression.

## Test data

The data files are the same standard cell inverters as in test 23, extracted from the standard cell libraries of the installed PDKs (`libs.ref/<stdcell-lib>/gds`) with KLayout:

- `<cell>.gds`: the inverter cell extracted from the library GDS
- `<cell>.mag` (ihp-sg13g2): magic-native view written by magic from the GDS
- `<cell>_wrongtop.gds` (ihp-sg13g2): top cell renamed so it does not match the file name, triggers the top cell guard
- `<cell>.klay.gds` (ihp-sg13g2): the inverter saved by KLayout with library context (the `.klay.klib` file is KLayout's library reference belonging to it). The file carries an extra `$$$CONTEXT_INFO$$$` top cell that the GDS top cell guard must tolerate, and the `.klay` marker in the file name is stripped when deriving the cell name. Magic logs a harmless unknown-layer complaint for the context cell and reads on.

One more cell is not an inverter but generated with KLayout:

- `sky130_pin_without_drawing.gds` (sky130A): a met1 box and next to it a met1.pin box (68/16) without met1 drawing below. The sky130 pin check flags the pin and exits with status 2, which `sak-drc.sh` must report as a finding (exit 1), not as a failed run (exit 7).

## Expected-dirty baselines

Some runs are pinned to exit 1 on purpose. A standard cell in isolation violates rules that are only satisfied at row or chip level, and these cases prove that the violation detection and reporting work:

- **sky130A `-m`**: magic flags the missing-tap rules (`nwell.4`, `LU.2`, `LU.3`) because taps sit in separate tap cells
- **gf180mcuD `-k` (all levels)**: the isolated 5V cell violates the dualgate rules `DF.13_MV`/`DF.14_MV`, which are satisfied only by row composition
- **sky130A `sky130_pin_without_drawing` `-k`**: the pin check flags the pin shape without drawing below it. The deck exits non-zero when it finds something, so this case also proves that such a status is not mistaken for a crashed deck
- **ihp-sg13g2 / ihp-sg13cmos5l `-k -l regular`**: the chip-level density/fill rules (`M*.j`, `TM*.c`, `GFil.g`, `AFil.g`) fail on a single cell, while `precheck` and `macro` skip density and are clean

If a PDK or tool update changes one of these verdicts, the test flags it so the baseline can be reviewed (and relaxed or tightened deliberately).
