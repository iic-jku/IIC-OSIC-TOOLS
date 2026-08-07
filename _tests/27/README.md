# Test 27: KLayout PCells smoke/regression test

`test_klayout_pcells.sh` instantiates every KLayout PCell of every supported
PDK and checks that it produces geometry.

For each PDK (`sky130A`, `gf180mcuD`, `ihp-sg13g2`, `ihp-sg13cmos5l`) the test:

- sources `sak-pdk-script.sh <pdk>` and launches KLayout in batch mode
  (`klayout -zz -r check_pcells.py`), which auto-loads the PDK's KLayout PCell
  libraries;
- discovers every PCell library the PDK registers (skipping KLayout's built-in
  `Basic`/`DEFAULT` libraries);
- instantiates every PCell once with its **default parameters** and classifies
  the result:
  - **OK** — the cell (including its instance hierarchy) contains at least one
    shape;
  - **EMPTY** — instantiation succeeded but produced no geometry at all;
  - **ERROR** — `create_cell` raised a Python exception;
- compares the outcome against a pinned per-PDK baseline in `check_pcells.py`
  and fails on any deviation.

The verdict is the whole point: a PCell that silently produces an empty cell,
or throws while producing, is broken from a designer's point of view (dropping
it in the layout editor yields nothing / an error).

Each PDK runs in its own subshell and its own **writable** work dir, because
the gdsfactory-based `sky130A` and `gf180mcuD` PCells write a temporary GDS into
the current directory while producing geometry.

The test reports only its per-PDK `[PASS]`/`[FAIL]` verdict on the console; the
per-PCell classification and the full KLayout output go into the log. Set
`PCELL_TEST_VERBOSE=1` to get the per-PDK verdicts on the console while
debugging a regression.

## PCell inventory (baseline)

| PDK              | Library / libraries                                          | PCells |
| ---------------- | ------------------------------------------------------------ | ------ |
| sky130A          | `skywater130`                                                 | 18     |
| gf180mcuD        | `gf180mcu` + `gf180mcu_klayoutapi` + `gf180mcu_sealring`      | 61     |
| ihp-sg13g2       | `SG13_dev` + `SG13_native_pcell_lib`                          | 37     |
| ihp-sg13cmos5l   | `SG13_dev`                                                    | 24     |

## Expected-dirty baselines

A few PCells produce an **empty** cell with their default parameters. They are
pinned in `check_pcells.py` (`known_bad`, keyed by `<library>/<pcell>`) so the
test is green on the current image while still failing on any regression. If a
PDK update changes one of these verdicts, the test flags it so the baseline can
be reviewed (relaxed, tightened, or removed once fixed upstream):

- **gf180mcuD `gf180mcu_klayoutapi/efuse`**: `draw_efuse()` is called without its
  required `device_name` argument and raises `TypeError`.

The classic `gf180mcu` library produces the same devices correctly, and the IHP
PDKs (`ihp-sg13g2`, `ihp-sg13cmos5l`) as well as sky130A instantiate all their
PCells cleanly.

## Runaway PCells

Some PCells cannot be instantiated at all: their generator allocates without
bound until the kernel OOM-kills KLayout, which loses the verdict for the whole
PDK and starves whatever runs next to this test in the suite. They are listed
per PDK in `check_pcells.py` (`runaway`), reported as **SKIPPED**, and still
counted in the inventory, so a rename or an upstream fix is flagged:

- **gf180mcuD `gf180mcu_klayoutapi/diode_dw2ps`, `.../diode_pw2dw`**: the
  generator recurses in `Cell.flatten` (`draw_diode.py`) — 95 s and >6 GB for
  `diode_dw2ps` before `std::bad_alloc`, past 15 GB when left unbounded. The
  same devices from the classic `gf180mcu` library are produced correctly.

As a backstop for a *new* runaway, the wrapper watches the resident memory of
each KLayout run and kills it above `PCELL_TEST_RSS_LIMIT_KB` (default 8 GiB;
a healthy run peaks around 550 MB). The PDK is then reported as failed with the
measured RSS in the log, instead of dying to the kernel OOM killer.

This is deliberately not `ulimit -v`: that caps the virtual address space, and
OpenBLAS — pulled in via numpy by the gdsfactory-based sky130A and gf180mcuD
PCells — reserves large per-thread arenas up front. On a machine with many cores
those reservations alone blow any sane limit and KLayout dies with
`OpenBLAS error: Memory allocation still failed after 10 retries` before
instantiating a single PCell.

## What makes the test fail

`check_pcells.py` exits non-zero (→ `[FAIL]`) when:

- a PCell that is expected OK becomes EMPTY or ERROR (**regression**);
- a pinned known-bad PCell starts working or changes its failure mode
  (**baseline changed** — update `known_bad`);
- the number of registered PCells changes (**inventory drift** — a PCell was
  added or removed);
- a pinned known-bad PCell can no longer be found (renamed or removed).

To adjust the baseline after an intentional PDK change, edit the `EXPECTED`
table in `check_pcells.py`.
