# Important information

In order to run this example with OpenLane2, you need to consider the following things:

1. The default PDK in the latest image is `ihp-sg13g2`, but there is no proper OpenLane setup yet. Please switch the PDK by e.g. doing `sak-pdk sky130A` before starting OpenLane2 with `openlane`.
2. The directory `/foss/examples/demo_sky130A/dig` is read-only, so you should copy the files first to e.g. `/tmp`.

Here is a recipe that works:

```bash
cp -R /foss/examples/demo_sky130A/dig /tmp/dig
cd /tmp/dig
sak-pdk sky130A
openlane counter.json
```
