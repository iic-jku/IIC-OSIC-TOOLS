# LibreLane example for ASAP7

An 8-bit counter at 1 GHz (`CLOCK_PERIOD` is in ps, the time unit of the ASAP7 Liberty files). Copy this directory and run:

```bash
sak-pdk asap7
librelane config.json
```

The settings in `config.json` that every ASAP7 design needs:

* `meta.substituting_steps` removes the Magic and Netgen steps. ASAP7 has no Magic technology, the flow signs off with KLayout stream-out and KLayout DRC.
* `RUN_ANTENNA_REPAIR: false`, ASAP7 has no antenna rules and no diode cell.
* `IO_PIN_H_THICKNESS_MULT` and `IO_PIN_V_THICKNESS_MULT` at 1. Pins at twice the wire width give rect-only violations on M4 and M5 where the router lands on them.
* `ERROR_ON_KLAYOUT_DRC: false`. The KLayout deck reports violations inside some library cells (TIEHIx1, DFFASRHQNx1) and in some via definitions of the tech LEF. Check the report in the `klayout-drc` step.

LVS runs after the flow on the final GDS, with the CDL written by OpenROAD:

```bash
R=$(ls -td runs/*/ | head -1)
CDL=$PDK_ROOT/asap7/libs.ref/asap7sc7p5t/cdl/asap7sc7p5t_28_R.cdl
printf 'read_db %s/final/odb/counter.odb\nwrite_cdl -include_fillers -masters %s counter.cdl\n' "$R" "$CDL" > write_cdl.tcl
openroad -exit -no_init write_cdl.tcl
cat counter.cdl "$CDL" > counter_lvs.cdl
klayout -b -r "$PDK_ROOT/asap7/libs.tech/klayout/lvs/asap7.lvs" -rd input="$R/final/gds/counter.gds" \
    -rd topcell=counter -rd schematic="$PWD/counter_lvs.cdl" -rd report="$PWD/counter.lvsdb"
```
