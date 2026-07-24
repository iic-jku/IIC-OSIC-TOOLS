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

| PDK              | Library / libraries                     | PCells |
| ---------------- | --------------------------------------- | ------ |
| sky130A          | `skywater130`                           | 18     |
| gf180mcuD        | `gf180mcu`                              | 29     |
| ihp-sg13g2       | `SG13_dev` + `SG13_native_pcell_lib`    | 34     |
| ihp-sg13cmos5l   | `SG13_dev`                              | 23     |

## Expected-dirty baselines

A few PCells produce an **empty** cell with their default parameters. They are
pinned in `check_pcells.py` (`known_bad`) so the test is green on the current
image while still failing on any regression. If a PDK update changes one of
these verdicts, the test flags it so the baseline can be reviewed (relaxed,
tightened, or removed once fixed upstream):

- **sky130A `p_diode`**: the PCell code calls an unsupported gdsfactory boolean
  operation (`"A-B"`); KLayout logs the `ValueError` and returns an empty cell.
- **gf180mcuD `pfet`**: draws nothing with the default parameter set, even
  though `nfet` — which has the identical defaults — is fine.
- **gf180mcuD `via_dev`**: `base_layer`/`metal_level` default to `None`, so no
  via is drawn.

The IHP PDKs (`ihp-sg13g2`, `ihp-sg13cmos5l`) instantiate all their PCells
cleanly.

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
