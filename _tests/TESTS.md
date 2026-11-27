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

Logs, work dirs and cloned repositories of a full run add up to several GB, so they are *not* written into this source tree (which is bind-mounted into the container) but into `/tmp/iic-osic-tools-tests/<run-id>`. `run_integration_tests.sh` prints the exact location at the start of the run.

Each test logs to `logs/<NN>_<test>.log` in the run dir and writes its work files below `<NN>/`. When a test passes, both are deleted right away, so after the run the run dir holds the joblog (`joblog.tsv`, runtime and exit status of every test) and the logs and work dirs of the failed tests only. Set `IIC_TEST_KEEP_PASSED=1` to keep the data of the passing tests as well. The run dir itself stays for post-mortem analysis, so remove old run dirs manually when you no longer need them.

## Progress display

On a terminal the runner shows one live status line instead of the output of every test: a progress bar, finished and failed counts, the elapsed time and the tests still running. A failing test is printed above that line as soon as it finishes, with the path to its log and its last `[ERROR]` lines. The container's own output (the summary at the end, parallel messages) goes to `runner.log` in the run dir and is printed when the run is done. Ctrl-C stops the container.

Redirected output (a file, a pipe, CI) keeps the plain output of every test, and `IIC_TEST_PROGRESS=0` selects that on a terminal too.

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
| 03       | Import of Python packages (and the `gdsfill` CLI, which is no longer a Python package)                                           |
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
| 21       | [analog circuit design](https://github.com/iic-jku/analog-circuit-design) xschem/ngspice simulation testbenches with ihp-sg13cmos5l |
| 22       | [SPARX](https://github.com/iic-jku/SG13CMOS_SPARX) six-port receiver with ihp-sg13g2                                            |
| 23       | Smoke/regression test of sak-lvs.sh (all PDKs, Magic+Netgen and KLayout)                                                        |
| 24       | Smoke/regression test of sak-drc.sh (all PDKs, Magic, KLayout and gdscheck)                                                     |
| 25       | Smoke/regression test of sak-pex.sh (all PDKs and PEX modes, Magic and kpex 2.5D)                                               |
| 26       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with ihp-sg13g2             |
| 27       | KLayout PCells smoke/regression test (instantiate all PCells of all PDKs, flag empty cells and errors)                          |
| 28       | [TinyWhisper](https://github.com/iic-jku/TinyWhisper) multi-mode short-wave transmitter with ihp-sg13g2                         |
| 29       | cap_cmomi MoM capacitor with ihp-sg13cmos5l (ngspice OSDI and VACASK model conversion)                                          |
| 30       | xdg-mime defaults (every design file type resolves to its intended application, and covers all of sak-open.py)                  |
| 31       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with ihp-sg13cmos5l         |
| 32       | [AMS chip template](https://github.com/iic-jku/ihp-sg13cmos5l-ams-chip-template) with ihp-sg13cmos5l                            |
| 33       | FPGA place-and-route flows (an iCE40 and an ECP5 blinky through synthesis, place-and-route and bitstream packing)               |
| 34       | KLayout GUI DRC/LVS run directory patch of both IHP PDKs (resolved against the layout file, `%top_cell%` placeholder)           |
| 35       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) PEX bench (Magic, kpex 2.5D) with all PDKs  |
| 36       | VACASK model conversion of both IHP PDKs (corner sections and xschem models symbol load, MOSCAP/MoM/Schottky against ngspice)   |
| 37       | VACASK `absdelay` (OSDI 0.5 compiler and shipped models, compiler found without `$TOOLS/bin` on `PATH`, ideal line delay)       |
| 38       | KLayout standard-cell libraries of both IHP PDKs (LV and HV cells registered for the Instance dialog)                           |
| 39       | PyOPUS with ngspice (performance evaluator, cost report, threaded PySide6 plotter, GUI import)                                  |
| 40       | ngspice mixed-signal co-simulation (`d_cosim` counter with Icarus Verilog through `ivlng` and Verilator through `vlnggen`)      |
| 41       | Verilator FST tracing (`--binary --trace-fst` model build, run and dump read-back with `fst2vcd`)                               |
| 42       | Verilator with UVM (`--binary` hello-world `uvm_test` against `$UVM_HOME`, package with and without DPI)                        |
| 43       | `run_palace` with two MPI processes (ihp-sg13g2 inductor example meshed by gds2palace, one frequency at order 1)                |
| 44       | `USER` in a login shell started like a `docker exec`, without nss_wrapper (one line, matches `getpass.getuser()`)               |
| 45       | `buildxyceplugin` compiles a Verilog-A model into a Xyce plugin (ihp-sg13g2 `r3_cmc`, same results as the PDK's prebuilt one)   |
| 46       | KQCircuits standalone export (non-root, output paths, layout and simulation inputs, scikit-rf postprocessing)                 |
| 47       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with gf180mcuD              |
| 48       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (DRC, LVS, PEX) with sky130A                |
| 49       | [VLSI design](https://github.com/iic-jku/vlsi-design) course examples (lint, simulation, synthesis, STA, DFT, LibreLane) with ihp-sg13cmos5l |
| 50       | LibreLane started without its wrapper (`python3 -m librelane`, Python API) runs an OpenROAD with `-python` support            |
| 51       | Netgen derives the MIM capacitor area of the SG13G2 setup in every run directory (wrong sizes fail, matching sizes pass)        |
| 52       | Icarus Verilog elaborates and simulates a flip-flop of the SG13G2 and SG13CMOS5L standard cells with `-gspecify`                |
| 53       | LibreLane with gf180mcuD and the 3.3V standard cells `gf180mcu_as_sc_mcu7t3v3`                                                  |
| 54       | `sak-report.py` summarizes KLayout and Magic DRC reports and rejects missing, truncated, crashed and stale ones                 |
| 55       | `sak-report.py` summarizes KLayout and Netgen LVS reports of a matching and a mismatching sky130A inverter                      |
| 56       | `sak-gds-info.py` reports layers, bounding box, cell tree and labels of a layout and rejects missing files and ambiguous top cells |
| 57       | `sak-job.py` runs commands detached, waits for them, reads their log, cancels them with their children and flags lost jobs      |
| 58       | `sak-render.py` keeps its default output, renders a `--bbox` region and reports files, region and scale with `--json`          |
| 59       | LibreLane with ics55 (counter), KLayout DRC with `sak-drc -k`, KLayout LVS with `sak-lvs -k` that matches the design and rejects a changed connection |
| 60       | ASAP7 BSIM-CMG models in ngspice, Xyce and VACASK against the per-fin targets of the ASAP7 paper, xschem testbenches and the VACASK example |
| 61       | KLayout LVS of the ASAP7 RVT standard cells against their CDL (known mismatches listed), a wrong fin count, and the DRC deck on INVx1 |
| 62       | LibreLane example of ASAP7 (8-bit counter at 1 GHz) with KLayout LVS of the final GDS and a negative LVS check                  |
| 63       | pygmid lookup tables of the ASAP7 RVT devices from `techsweep_asap7.py`                                                        |
| 64       | SAK commands with asap7: `sak-drc.sh` and `sak-lvs.sh` refuse Magic and run KLayout with `-k` (JSON results, a wrong fin count fails), layer names in `sak-gds-info.py` and `sak-render.py` |
| 65       | ASAP7 analog devices (FinFETs with their gate lengths, IO FinFETs, junction diodes and vertical PNP, MOS capacitors, metal and thin-film resistors, MOM capacitor): values in ngspice, Xyce and VACASK, mismatch, xschem testbench, KLayout LVS (also with body nets) and DRC of generated layouts, of every PCell and of the routed example, wire capacitance extraction, negative checks |
| 66       | Icarus Verilog elaborates and simulates a flip-flop of the sky130 HD standard cells with `-gspecify` (timing checks with timestamp/timecheck conditions) |
| 67       | gf180mcuD 3.3 V IO and SRAM: OpenROAD links and times `gf180mcu_ocd_ip_sram` and `gf180mcu_ocd_io` at the 3.3 V corners LibreLane uses |
| 68       | `sak-via-redundancy.py` on small SG13G2 layouts with a known number of net-opening cuts (with and without room for a second cut, a cut pair, a stub, a loop, a contact column, a dangling via) and its exit codes |
| 69       | `sak-current-density.py` on small SG13G2 layouts with hand-computed results: wire and via ratios and the IR drop of the resistive solve, the floor and the screen, a black-box macro with a current view, a view kept after a rewrite with the same content and refused after a change, a macro checked on its own, and the exit codes |
