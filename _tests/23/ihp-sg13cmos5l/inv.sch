v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 380 -310 380 -270 {lab=Y}
N 380 -270 380 -230 {lab=Y}
N 380 -270 460 -270 {lab=Y}
N 340 -340 340 -270 {lab=A}
N 340 -270 340 -200 {lab=A}
N 280 -270 340 -270 {lab=A}
N 380 -400 380 -370 {lab=VDD}
N 380 -170 380 -140 {lab=VSS}
N 380 -340 420 -340 {lab=VDD}
N 420 -400 420 -340 {lab=VDD}
N 380 -400 420 -400 {lab=VDD}
N 380 -200 420 -200 {lab=VSS}
N 420 -200 420 -140 {lab=VSS}
N 380 -140 420 -140 {lab=VSS}
C {sg13cmos5l_pr/sg13_lv_nmos.sym} 360 -200 0 0 {name=M1
l=0.13u
w=0.74u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
C {sg13cmos5l_pr/sg13_lv_pmos.sym} 360 -340 0 0 {name=M2
l=0.13u
w=1.12u
ng=1
m=1
model=sg13_lv_pmos
spiceprefix=X
}
C {ipin.sym} 280 -270 0 0 {name=p1 lab=A}
C {opin.sym} 460 -270 0 0 {name=p2 lab=Y}
C {iopin.sym} 380 -400 3 0 {name=p3 lab=VDD}
C {iopin.sym} 380 -140 1 0 {name=p4 lab=VSS}
