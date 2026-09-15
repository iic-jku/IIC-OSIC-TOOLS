# Test 35: PEX bench of the open-pdks regression tests, all PDKs

`test_pex_bench.sh` runs the PEX bench of
[open-pdks-regression-tests](https://github.com/iic-jku/open-pdks-regression-tests)
for all four PDKs of the image and reports one verdict for the lot.

A PEX bench is a set of metal-only dummy layouts whose parasitics follow from
the PDK extraction deck by hand: a plate and a wire over substrate, a plate over
a plate, two wires at swept spacing, wires and via chains with two ports, tees
and a cross. The values extracted from them are pinned in the bench, so the test
notices when a new Magic, KLayout, kpex or PDK in the image extracts different
numbers from unchanged layouts and an unchanged deck. It checks for change, not
for correctness: which pinned values encode known extractor defects is written
up in the bench repository, see `ihp-sg13g2/pex_bench/README.md` there.

The test:

- clones the `main` branch of the regression repository (shallow, incl.
  submodules) into the run dir and marks it a `safe.directory`, since the
  container user is usually not the owner of the checkout;
- runs, per PDK in `<pdk>/pex_bench/`:
  - `make layouts`, which regenerates the layouts from `scripts/gen_*.py`, so
    the extraction runs on what the generators produce;
  - `make pex-bench-magic`, Magic PEX in all three modes on every layout;
  - `make pex-bench-2.5d`, the kpex 2.5D engine on the comparison cells, if the
    bench lists `kpex25` in `PEX_ENGINES` (see below);
  - `make pex-bench-compare`, which builds the comparison tables and writes
    `runs/results.json`;
  - `scripts/check_results.py`, which compares `runs/results.json` against
    `expected/results.json`;
- passes when every step of every PDK succeeds and no value moved.

The bench switches the PDK itself (its `Makefile` sets `EXPECTED_PDK`, and
`common.mk` calls `sak-pdk` with it), so unlike test 25 this test does not source
`sak-pdk-script.sh`.

| PDK              | Layouts | Pinned values | Engines          |
| ---------------- | ------- | ------------- | ---------------- |
| ihp-sg13g2       | 63      | 208           | Magic, kpex 2.5D |
| ihp-sg13cmos5l   | 54      | 126           | Magic            |
| gf180mcuD        | 50      | 145           | Magic, kpex 2.5D |
| sky130A          | 58      | 156           | Magic, kpex 2.5D |

The numbers are those at the time of writing; the bench repository is the
reference.

## Engines per PDK

Which engines a PDK runs is the bench's own statement, in `PEX_ENGINES` in
`<pdk>/pex_bench/Makefile`; the test reads it and does not decide it. An engine
the PDK's tooling cannot run on an unmodified image is not called at all rather
than failing on every run.

`ihp-sg13cmos5l` currently lists only `magic`: the kpex wheel ships the
`sg13cmos5l` LVS deck without the rule decks it includes, so kpex fails before
it extracts anything. The PDK is reported as `pass (no kpex)`, and its deck and
Magic values are still checked in full. Once kpex is fixed, `kpex25` goes back
into `PEX_ENGINES` in the bench repository; nothing changes here.

The FasterCap field solve of the bench (`make pex-bench FASTERCAP=1`) is not
run. It takes minutes per cell, and the value check treats its column as
optional.

## Verdict

Only the verdict goes to the console. It names the outcome of every PDK, for
example:

```text
[INFO] Test <PEX bench, all PDKs> passed. ihp-sg13g2 pass, ihp-sg13cmos5l pass (no kpex), gf180mcuD pass, sky130A pass (19 checks).
```

A failing case prints its own `[FAIL]` line, followed by the few output lines
that say what went wrong (the failing make target, the drifted values, the
verdict of the value check). The first failure of a PDK becomes its entry in the
verdict line:

| Entry                | Meaning                                                                                   |
| -------------------- | ----------------------------------------------------------------------------------------- |
| `failed at <step>`   | a make step failed: layout generation, an extraction, or the tables                       |
| `DRIFT`              | Magic or kpex extracts different values than when the bench was blessed                   |
| `DECK`               | a hand-maintained deck constant in the bench scripts changed                              |
| `MISSING`            | expected values were not produced, so an extraction did not complete                      |
| `USAGE`              | the value check was called wrongly, or `expected/results.json` is missing                 |
| `no bench`           | the clone has no `<pdk>/pex_bench/Makefile`                                               |

`DRIFT`, `DECK`, `MISSING` and `USAGE` are the exit codes 2, 1, 3 and 4 of `check_results.py`, which
compares deck, Magic and kpex 2.5D values to 0.05 %. Every step runs even when an
earlier one failed, and every PDK runs even when another one failed.

The clone output and the full transcript of every step are in
`$IIC_TEST_RUNDIR/<run-id>/35/pex_bench_test.log` (default
`/tmp/iic-osic-tools-tests/...`, see [../TESTS.md](../TESTS.md)). Set
`SAK_TEST_VERBOSE=1` to see every case on the console, passing ones included.

## When the test fails

A `DRIFT` after an image update is what this test is for. Look up which values
moved and by how much in the log, and decide whether the tool change is a fix or
a regression. Only then bless the new values in the bench repository with
`make pex-bench-expected` in `<pdk>/pex_bench/`, naming the tool versions in the
commit. Re-blessing to make a failing run pass defeats the test.

## Runtime

Between about 600 s and 1200 s standalone for all four PDKs, in three runs on a
laptop with `iic-osic-tools:next` 2026.09. Its runtime under contention is not
measured yet.
