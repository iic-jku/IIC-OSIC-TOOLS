# Test 47: open-pdks regression tests with gf180mcuD

`test_drc_lvs_pex_gf180mcud.sh` runs the DRC / LVS / PEX regression suite of
[open-pdks-regression-tests](https://github.com/iic-jku/open-pdks-regression-tests)
against the `gf180mcuD` PDK of the image. It is a sibling of tests 26 and 31,
which do the same for `ihp-sg13g2` and `ihp-sg13cmos5l`.

The test:

- clones the `main` branch of the regression repository (shallow, incl.
  submodules) into the run dir and marks it a `safe.directory`, since the
  container user is usually not the owner of the checkout;
- switches to the PDK with `source sak-pdk-script.sh gf180mcuD gf180mcu_fd_sc_mcu7t5v0`;
- runs `make regression` in `gf180mcuD/`, which takes every `.gds` in
  `layout/` through the steps in `REGRESSION_STEPS` (DRC, LVS and PEX with
  KLayout and Magic, see the `README.md` of that directory);
- passes when the Makefile's regression summary reports no unexpected failure.

Only the verdict goes to the console; the clone output and the full
`make regression` transcript are in
`$IIC_TEST_RUNDIR/<run-id>/47/drc_lvs_pex_gf180mcud.log` (default
`/tmp/iic-osic-tools-tests/...`, see [../TESTS.md](../TESTS.md)). Set `DEBUG=1`
for progress messages while debugging.

## Known failures

The verdict is the summary of `make regression`. Which steps may fail, and
which have to, is listed in `gf180mcuD/Makefile` of the regression
repository and explained next to it, in `KNOWN_ISSUES.md` and
`EXPECTED_FAILS.md` (PDK quirks and work-arounds are in `FINDINGS.md`). A listed
failure that starts passing is an `UNEXPECTED PASS` and fails the test, so a
tool fix shows up here and the entry can be removed.

The lists are deliberately **not** duplicated here, so that they have only one
place to be kept up to date.

## Differences to test 26

The script is a straight port of `26/test_drc_lvs_pex_sg13g2.sh`; the only
differences are the PDK name, the standard cell library, the subdirectory of the
regression repo, and the log/run-dir names. Everything PDK-specific (cell list,
`KNOWN_FAILS`) lives in the regression repository, not here.
