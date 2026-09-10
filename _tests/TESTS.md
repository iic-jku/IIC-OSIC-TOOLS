# Regression tests

## Container engine

`run_integration_tests.sh` runs on Podman as well as Docker and picks the engine
itself: Podman first when both are installed, since a test run needs no daemon
and is happy rootless. Override the choice with `CONTAINER_ENGINE`:

```bash
CONTAINER_ENGINE=docker ./run_integration_tests.sh hpretl/iic-osic-tools:latest
```

Under *rootless* Podman on Linux the runner adds `--userns=keep-id` by itself,
so the bind-mounted source tree and the run dir stay writable for the container
user (same reasoning as [Section 5.1 of the README](../README.md#51-podman)). On
macOS the podman machine already maps the host user, so nothing is added there.

## Test output

Logs, work dirs and cloned repositories of a full run add up to several GB, so they are *not* written into this source tree (which is bind-mounted into the container) but into `/tmp/iic-osic-tools-tests/<run-id>`. `run_integration_tests.sh` prints the exact location at the start of the run and keeps it afterwards for post-mortem analysis, so remove old run dirs manually when you no longer need them.

Set `IIC_TEST_RUNDIR=<path>` to collect the output somewhere else, for example on a larger volume:

```bash
IIC_TEST_RUNDIR=/mnt/scratch/osic-tests ./run_integration_tests.sh hpretl/iic-osic-tools:latest
```

## Scheduling

All tests run concurrently in a GNU parallel pool (one job per core). Since parallel starts the jobs in input order, the wall clock of a run is set by the longest test that starts last, so `run_integration_tests.sh` feeds the known long runners first via its `SLOW_TESTS` list. Keep that list roughly ordered by runtime; entries that are stale only cost wall clock, they never break a run.

Test 21 additionally runs its own (small) inner pool of simulation jobs; use `ACD_JOBS=<n>` to change its size.

## Test list

| Test No. | Description                                                                                                                     |
| -------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 01       | LibreLane with sky130A                                                                                                          |
| 02       | DRC and LVS with sky130A                                                                                                        |
| 03       | Import of Python packages                                                                                                       |
| 04       | LibreLane with gf180mcuD                                                                                                        |
| 05       | ngspice with SG13G2                                                                                                             |
| 06       | ngspice with sky130A                                                                                                            |
| 07       | LibreLane with sky130A and VHDL                                                                                                 |
| 08       | PULP flow                                                                                                                       |
| 09       | RISC-V toolchain                                                                                                                |
| 10       | OpenROAD flow scripts with SG13G2                                                                                               |
| 11       | Xyce with SG13G2                                                                                                                |
| 12       | iVerilog functionality                                                                                                          |
| 13       | <https://www.zerotoasiccourse.com> examples of Matt Venn (disabled; known fail)                                                 |
| 14       | ngspice with gf180mcuD                                                                                                          |
| 15       | Chisel with a simple example ALU                                                                                                |
| 16       | VACASK with a simple example                                                                                                    |
| 17       | Veryl                                                                                                                           |
| 18       | LibreLane with ihp-sg13g2                                                                                                       |
| 19       | LibreLane with ihp-sg13cmos5l                                                                                                   |
| 20       | [AMS chip template](https://github.com/iic-jku/ihp-sg13g2-ams-chip-template) with ihp-sg13g2                                    |
| 21       | [analog circuit design](https://github.com/iic-jku/analog-circuit-design) xschem/ngspice simulation testbenches with ihp-sg13g2 |
| 22       | [SPARX](https://github.com/iic-jku/SG13CMOS_SPARX) six-port receiver with ihp-sg13g2                                            |
| 23       | Smoke/regression test of sak-lvs.sh (all PDKs, Magic+Netgen and KLayout)                                                        |
| 24       | Smoke/regression test of sak-drc.sh (all PDKs, Magic and KLayout)                                                               |
| 25       | Smoke/regression test of sak-pex.sh (all PDKs and PEX modes)                                                                    |
| 26       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with ihp-sg13g2             |
| 27       | KLayout PCells smoke/regression test (instantiate all PCells of all PDKs, flag empty cells and errors)                          |
| 28       | [TinyWhisper](https://github.com/iic-jku/TinyWhisper) multi-mode short-wave transmitter with ihp-sg13g2                         |
| 29       | cap_cmomi MoM capacitor with ihp-sg13cmos5l (ngspice OSDI and VACASK model conversion)                                          |
| 30       | xdg-mime defaults (every design file type resolves to its intended application, and covers all of sak-open.py)                  |
| 31       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with ihp-sg13cmos5l         |
| 32       | [AMS chip template](https://github.com/iic-jku/ihp-sg13cmos5l-ams-chip-template) with ihp-sg13cmos5l                            |
| 33       | FPGA place-and-route flows (an iCE40 and an ECP5 blinky through synthesis, place-and-route and bitstream packing)               |
| 34       | KLayout GUI DRC/LVS run directory patch of both IHP PDKs (resolved against the layout file, `%top_cell%` placeholder)           |
