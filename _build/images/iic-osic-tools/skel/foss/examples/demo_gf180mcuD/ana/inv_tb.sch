v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 640 -330 640 -290 {lab=GND}
N 760 -330 760 -290 {lab=GND}
N 640 -450 640 -390 {lab=VDD}
N 760 -420 760 -390 {lab=in}
N 760 -420 870 -420 {lab=in}
N 950 -550 950 -500 {lab=VDD}
N 950 -340 950 -290 {lab=GND}
N 1020 -420 1110 -420 {lab=out}
C {devices/title.sym} 170 -40 0 0 {name=l1 author="M. Koefinger"}
C {inv.sym} 870 -500 0 0 {name=xinv1}
C {devices/vsource.sym} 640 -360 0 0 {name=V1 value=3.3 savecurrent=false}
C {devices/vsource.sym} 760 -360 0 0 {name=VIN value=3.3 savecurrent=false}
C {devices/vdd.sym} 640 -450 0 0 {name=l2 lab=VDD}
C {devices/vdd.sym} 950 -550 0 0 {name=l3 lab=VDD}
C {devices/gnd.sym} 640 -290 0 0 {name=l4 lab=GND}
C {devices/gnd.sym} 760 -290 0 0 {name=l5 lab=GND}
C {devices/gnd.sym} 950 -290 0 0 {name=l6 lab=GND}
C {devices/noconn.sym} 1110 -420 0 1 {name=l7}
C {devices/lab_wire.sym} 820 -420 0 0 {name=p1 sig_type=std_logic lab=in}
C {devices/lab_wire.sym} 1080 -420 0 0 {name=p2 sig_type=std_logic lab=out}
C {devices/code_shown.sym} 20 -150 0 0 {name=MODELS only_toplevel=true
format="tcleval( @value )"
value="
.include $::180MCU_MODELS/design.ngspice
.lib $::180MCU_MODELS/sm141064.ngspice typical
"}
C {devices/code_shown.sym} 20 -890 0 0 {name=NGSPICE only_toplevel=true
value="

.control
save all

** Define input signal
let fsig = 1k
let tper = 1/fsig
let tfr = 0.01*tper
let ton = 0.5*tper-2*tfr

** Define transient params
let tstop = 2*tper
let tstep = 0.001*tper

** Set Sources
alter @VIN[DC] = 0.0
alter @VIN[PULSE] = [ 0 3.3 0 $&tfr $&tfr $&ton $&tper 0 ]

** Simulations
op
dc vin 0 3.3 0.01
tran $&tstep $&tstop

** Plots
setplot dc1
let vout = v(out)
plot vout

setplot tran1
let vout = v(out)
let vin = v(in)
let ivdd = -v1#branch*1e4
plot vout vin ivdd

setplot op1
write inv_tb.raw
.endc
"}
C {devices/launcher.sym} 710 -160 0 0 {name=h1
descr="Annotate OP"
tclcommand="set show_hidden_texts 1; xschem annotate_op"}
