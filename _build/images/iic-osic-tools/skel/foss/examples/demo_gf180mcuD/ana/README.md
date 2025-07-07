# Inverter Example

In this folder you can find the *"Hello World"* example of IC design: A simple analog inverter in the CMOS technology `gf180mcuD`.

A video tutorial on how to draw a simple inverter using `Xschem` and how to simulate it using `ngspice` is available on YouTube. Please follow this tutorial in your local installation of the IIC-OSIC-TOOLS.

- Tutorial using Xschem and ngspice with gf180mcu ([part 1](https://youtu.be/MdywD87-DVg))
- Tutorial using Xschem and ngspice with gf180mcu ([part 2](https://youtu.be/DLvZSsLAbho))
- Tutorial using Xschem and ngspice with gf180mcu ([part 3](https://youtu.be/nBnR8Nm_B_I))

A lot of useful information about analog design and how to operate `ngspice` you can find also in this [online analog circuit design course](https://iic-jku.github.io/analog-circuit-design/analog_circuit_design.html). Please note that it uses the `ihp-sg13g2` PDK.

A second video tutorial on how to draw the layout of the inverter using `KLayout` is also available on YouTube. Please follow this tutorial in your local installation of the IIC-OSIC-TOOLS.

- Tutorial using KLayout with gf180mcu ([part 4](https://youtu.be/vamfMryYPS4))

In addition, the following prepared files are available here for your reference:

- `inv.sch`: The schematic of the inverter, designed using `Xschem`.
- `inv.sym`: The symbol for the inverter, also designed using `Xschem`.
- `inv_tb.sch`: The testbench schematic for simulating the inverter, designed using `Xschem` and simulating with `ngspice`. Open this file in `Xschem` using `xschem inv_tb.sch`.
- `inv.gds`: An example layout of the inverter designed in `inv.sch`.
