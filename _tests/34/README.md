# Test 34: KLayout GUI DRC/LVS run directory

`test_klayout_run_dir.sh` checks the run-directory fix that `install_ihp.sh` and `install_ihp_cmos5l.sh` apply to the KLayout DRC and LVS menu macros of both IHP PDKs (`fix_klayout_run_dir.py`).

The IHP macros build their output directory as a relative name and expand it against the working directory of the KLayout process, so the same layout writes its reports somewhere else depending on how KLayout was started, and by default next to the layout rather than into the project's verification folder. The fix resolves a relative run directory against the layout file instead, replaces `%top_cell%` in it with the cell name, and changes the default so a layout whose directory has a `verification` folder beside it reports into `../verification/drc/<cell>.klayout-gui.drc` (and the LVS equivalent) with nothing to configure.

The `klayout-gui` tag is load-bearing: `sak-drc.sh -w` writes `<cell>.klayout.drc` into the same folder, those reports are committed in the IIC design templates, and the DRC macro deletes its run directory before every run. A shared name would let one menu click destroy a signoff result.

That fix is applied by matching the shipped macro text. A PDK bump that rewrites those lines makes it skip with a `[WARN]` in the build log, which is easy to miss, so this test is the alarm. Per PDK and for DRC and LVS it checks:

- the installed macro resolves its run directory against the layout file
- the installed macro substitutes `%top_cell%`
- no one-argument `File.expand_path(run_dir)` is left, which is what resolved against the working directory
- the installed macro defaults into a sibling `verification` folder, and tags that default so it cannot hit the batch run
- the options dialog documents `%top_cell%`, so the placeholder is discoverable where the value is typed
- macro and options dialog are still well-formed XML and still parse as Ruby, which is what a bad patch would break

It closes with the resolution itself, run from a working directory unrelated to the layout: a relative run directory follows the layout, an absolute one is left alone, an explicit relative one lands next to the layout, no layout falls back to the working directory, a cell name with a slash is sanitized into a single path component, the empty default picks the sibling `verification` folder when there is one and stays next to the layout when there is not, and an explicit setting still overrides the project default.

The test needs no display and runs no DRC, so it finishes in seconds. It reports only its verdict on the console, the per-case `[PASS]`/`[FAIL]` results and the full command output go into the log. Set `SAK_TEST_VERBOSE=1` to get every case on the console while debugging a regression.

Set `PDK_ROOT=<path>` to check a PDK tree other than the installed one.
