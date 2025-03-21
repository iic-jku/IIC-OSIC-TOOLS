v {xschem version=3.4.5 file_version=1.2
}
G {}
K {}
V {}
S {}
E {}
B 2 1450 -580 2250 -180 {flags=graph
y1=0
y2=6
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=1e-06
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0


dataset=-1
unitx=1
logx=0
logy=0
hilight_wave=0
color=4
node=in}
B 2 1450 -1030 2250 -630 {flags=graph
y1=0
y2=6
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=1e-06
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0


dataset=-1
unitx=1
logx=0
logy=0
hilight_wave=0
color=7
node=out}
T {(c) 2021-2025 Harald Pretl, JKU, IIC

Inverter Testbench

Here a simple inverter (cell "inv") is instantiated as a symbol, and this
can be simulated.} 420 -800 0 0 0.4 0.4 {}
N 520 -210 520 -150 { lab=GND}
N 520 -150 640 -150 { lab=GND}
N 640 -210 640 -150 { lab=GND}
N 640 -310 640 -270 { lab=in}
N 520 -490 520 -270 { lab=vdd_hi}
N 640 -150 880 -150 { lab=GND}
N 640 -310 900 -310 { lab=in}
N 880 -290 900 -290 { lab=GND}
N 880 -290 880 -150 { lab=GND}
N 880 -330 900 -330 { lab=vdd_hi}
N 880 -490 880 -330 { lab=vdd_hi}
N 520 -490 880 -490 { lab=vdd_hi}
N 520 -150 520 -130 { lab=GND}
N 880 -150 1300 -150 { lab=GND}
N 1300 -210 1300 -150 { lab=GND}
N 1300 -330 1300 -270 { lab=out}
N 1200 -330 1300 -330 { lab=out}
C {devices/code.sym} 80 -400 0 0 {name=TT_MODELS
only_toplevel=true
format="tcleval( @value )"
value="** manual skywater pdks install (with patches applied)
* .lib \\\\$::SKYWATER_MODELS\\\\/models/sky130.lib.spice tt

** opencircuitdesign pdks install
.lib \\\\$::SKYWATER_MODELS\\\\/sky130.lib.spice.tt.red tt

.param mc_mm_switch=0
.param mc_pr_switch=0
"
spice_ignore=false}
C {devices/launcher.sym} 130 -140 0 0 {name=h2 
descr="Simulate" 
tclcommand="xschem save; xschem netlist; xschem simulate"}
C {devices/vsource.sym} 520 -240 0 0 {name=V2 value=5
}
C {devices/lab_wire.sym} 590 -490 0 0 {name=l2 lab=vdd_hi}
C {devices/code_shown.sym} 50 -710 0 0 {name=NGSPICE
only_toplevel=true
value="
.control
*set filetype=ascii
*save all

op
tran 0.1n 1u

write tb_inv.raw
*exit

.endc
"}
C {devices/lab_wire.sym} 680 -310 0 0 {name=l3 lab=in}
C {devices/vsource.sym} 640 -240 0 0 {name=V5
value1="dc 5 "
value="dc 5 pulse 5 0 0 1n 1n 0.05u 0.1u"}
C {inv.sym} 1050 -310 0 0 {name=x1}
C {devices/gnd.sym} 520 -130 0 0 {name=l1 lab=GND}
C {devices/capa.sym} 1300 -240 0 0 {name=C1
m=1
value=10f

footprint=1206
device="ceramic capacitor"}
C {devices/lab_wire.sym} 1270 -330 0 0 {name=l4 lab=out
}
C {devices/launcher.sym} 340 -140 0 0 {name=h5
descr="Load waves" 
tclcommand="xschem raw_read $netlist_dir/tb_inv.raw tran"
}
C {devices/title.sym} 160 -30 0 0 {name=l5 author="(c) 2024-2025 Harald Pretl, IIC@JKU"}
C {devices/spice_probe.sym} 660 -490 0 0 {name=p1 attrs=""}
C {devices/spice_probe.sym} 740 -310 0 0 {name=p2 attrs=""}
C {devices/spice_probe.sym} 1300 -330 0 0 {name=p3 attrs=""}
