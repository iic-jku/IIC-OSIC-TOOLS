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
T {ASAP7 passive devices, ngspice} -170 -230 0 0 0.5 0.5 {}
T {Metal resistor, thin-film resistor, MOM capacitor and MOS capacitor are an IIC-OSIC-TOOLS addition, not part of ASAP7} -170 -190 0 0 0.3 0.3 {}
C {asap7/rm.sym} -100 -60 0 0 {name=R1
w=18n
l=1.8u
m=1
model=rm2
spiceprefix=X
}
C {lab_pin.sym} -100 -90 0 0 {name=p1 sig_type=std_logic lab=a}
C {gnd.sym} -100 -30 0 0 {name=l2 lab=GND}
C {vsource.sym} -100 80 0 0 {name=va value="dc 1 ac 1" savecurrent=false}
C {lab_pin.sym} -100 50 0 0 {name=p3 sig_type=std_logic lab=a}
C {gnd.sym} -100 110 0 0 {name=l4 lab=GND}
C {asap7/rtfr.sym} 100 -60 0 0 {name=R2
w=108n
l=1u
m=1
mm=0
model=rtfr
spiceprefix=X
}
C {lab_pin.sym} 100 -90 0 0 {name=p5 sig_type=std_logic lab=b}
C {gnd.sym} 100 -30 0 0 {name=l6 lab=GND}
C {gnd.sym} 80 -60 0 0 {name=l20 lab=GND}
C {vsource.sym} 100 80 0 0 {name=vb value="dc 1 ac 1" savecurrent=false}
C {lab_pin.sym} 100 50 0 0 {name=p7 sig_type=std_logic lab=b}
C {gnd.sym} 100 110 0 0 {name=l8 lab=GND}
C {asap7/cmom.sym} 300 -60 0 0 {name=C1
w=1u
l=2u
m=1
model=cmom_m4m7
spiceprefix=X
}
C {lab_pin.sym} 300 -90 0 0 {name=p9 sig_type=std_logic lab=c}
C {gnd.sym} 300 -30 0 0 {name=l10 lab=GND}
C {vsource.sym} 300 80 0 0 {name=vc value="dc 0 ac 1" savecurrent=false}
C {lab_pin.sym} 300 50 0 0 {name=p11 sig_type=std_logic lab=c}
C {gnd.sym} 300 110 0 0 {name=l12 lab=GND}
C {asap7/ncap_rvt.sym} 500 -60 0 0 {name=C2
l=20n
nfin=4
m=10
model=nmos_rvt
spiceprefix=X
}
C {lab_pin.sym} 500 -90 0 0 {name=p13 sig_type=std_logic lab=d}
C {gnd.sym} 500 -30 0 0 {name=l14 lab=GND}
C {vsource.sym} 500 80 0 0 {name=vd value="dc 0.7 ac 1" savecurrent=false}
C {lab_pin.sym} 500 50 0 0 {name=p15 sig_type=std_logic lab=d}
C {gnd.sym} 500 110 0 0 {name=l16 lab=GND}
C {code_shown.sym} -170 170 0 0 {name=MODELS
only_toplevel=true
value="tcleval(.lib $ASAP7_NGSPICE_MODELS/asap7.lib tt
)"}
C {code_shown.sym} 180 170 0 0 {name=CONTROL
only_toplevel=true
value=".control
op
let r_rm2 = -1/i(va)
let r_rtfr = -1/i(vb)
print r_rm2 r_rtfr
ac lin 1 1meg 1meg
let c_rtfr = -imag(i(vb))/(2*pi*1meg)
let c_cmom = -imag(i(vc))/(2*pi*1meg)
let c_ncap = -imag(i(vd))/(2*pi*1meg)
print c_rtfr c_cmom c_ncap
.endc
"}
