v {xschem version=3.4.8RC file_version=1.3
* SPDX-FileCopyrightText: 2026 Harald Pretl
* Johannes Kepler University, Department for Integrated Circuits
* SPDX-License-Identifier: Apache-2.0
}
G {}
K {}
V {}
S {}
F {}
E {}
T {ASAP7 inverter DC transfer curve, ngspice} -170 -230 0 0 0.5 0.5 {}
T {ASAP7 is a predictive PDK, not manufacturable} -170 -190 0 0 0.3 0.3 {}
N 220 -70 220 -90 {lab=VDD}
N 220 -10 220 10 {lab=vout}
N 220 -10 280 -10 {lab=vout}
N 180 -40 180 40 {lab=vin}
N 140 0 180 0 {lab=vin}
N 220 70 220 90 {lab=GND}
N 220 -40 240 -40 {lab=VDD}
N 240 -90 240 -40 {lab=VDD}
N 220 -90 240 -90 {lab=VDD}
N 220 40 240 40 {lab=GND}
N 240 40 240 90 {lab=GND}
N 220 90 240 90 {lab=GND}
C {asap7/pmos_rvt.sym} 200 -40 2 1 {name=M2
l=20n
nfin=3
model=pmos_rvt
spiceprefix=X
}
C {asap7/nmos_rvt.sym} 200 40 0 0 {name=M1
l=20n
nfin=3
model=nmos_rvt
spiceprefix=X
}
C {vsource.sym} -100 20 0 0 {name=vdd value=0.7 savecurrent=false}
C {vsource.sym} 0 20 0 0 {name=vin value=0 savecurrent=false}
C {gnd.sym} -100 50 0 0 {name=l1 lab=GND}
C {gnd.sym} 0 50 0 0 {name=l2 lab=GND}
C {gnd.sym} 220 90 0 0 {name=l3 lab=GND}
C {lab_pin.sym} -100 -10 0 0 {name=p1 sig_type=std_logic lab=VDD}
C {lab_pin.sym} 0 -10 0 0 {name=p2 sig_type=std_logic lab=vin}
C {lab_pin.sym} 140 0 0 0 {name=p3 sig_type=std_logic lab=vin}
C {lab_pin.sym} 220 -90 0 0 {name=p4 sig_type=std_logic lab=VDD}
C {lab_pin.sym} 280 -10 0 1 {name=p5 sig_type=std_logic lab=vout}
C {code_shown.sym} -170 120 0 0 {name=MODELS
only_toplevel=true
value="tcleval(.lib $ASAP7_NGSPICE_MODELS/asap7.lib tt
)"}
C {code_shown.sym} 120 120 0 0 {name=CONTROL
only_toplevel=true
value=".control
save all
dc vin 0 0.7 0.005
let gain = deriv(v(vout))
meas dc vm when v(vout)=v(vin)
print vm
wrdata inv_vtc_ngspice.txt v(vout)
.endc
"}
