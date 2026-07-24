# Regression tests

## Test output

Logs, work dirs and cloned repositories of a full run add up to several GB, so they are *not* written into this source tree (which is bind-mounted into the container) but into `/tmp/iic-osic-tools-tests/<run-id>`. `run_docker_tests.sh` prints the exact location at the start of the run and keeps it afterwards for post-mortem analysis, so remove old run dirs manually when you no longer need them.

Set `IIC_TEST_RUNDIR=<path>` to collect the output somewhere else, for example on a larger volume:

```bash
IIC_TEST_RUNDIR=/mnt/scratch/osic-tests ./run_docker_tests.sh hpretl/iic-osic-tools:latest
```

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
| 26       | [open-pdks regression tests](https://github.com/iic-jku/open-pdks-regression-tests) (LVS, DRC, PEX) with ihp-sg13g2             |
| 27       | KLayout PCells smoke/regression test (instantiate all PCells of all PDKs, flag empty cells and errors)                          |
