v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 380 -310 380 -270 {lab=ZN}
N 380 -270 380 -230 {lab=ZN}
N 380 -270 460 -270 {lab=ZN}
N 340 -340 340 -270 {lab=I}
N 340 -270 340 -200 {lab=I}
N 280 -270 340 -270 {lab=I}
N 380 -400 380 -370 {lab=VDD}
N 380 -170 380 -140 {lab=VSS}
N 380 -340 460 -340 {lab=VNW}
N 380 -200 460 -200 {lab=VPW}
C {gf180mcu_fd_pr/nfet_05v0.sym} 360 -200 0 0 {name=M1
L=0.60u
W=0.82u
nf=1
m=1
ad="'int((nf+1)/2) * W/nf * 0.18u'"
pd="'2*int((nf+1)/2) * (W/nf + 0.18u)'"
as="'int((nf+2)/2) * W/nf * 0.18u'"
ps="'2*int((nf+2)/2) * (W/nf + 0.18u)'"
nrd="'0.18u / W'" nrs="'0.18u / W'"
sa=0 sb=0 sd=0
model=nfet_05v0
spiceprefix=X
}
C {gf180mcu_fd_pr/pfet_05v0.sym} 360 -340 0 0 {name=M2
L=0.50u
W=1.22u
nf=1
m=1
ad="'int((nf+1)/2) * W/nf * 0.18u'"
pd="'2*int((nf+1)/2) * (W/nf + 0.18u)'"
as="'int((nf+2)/2) * W/nf * 0.18u'"
ps="'2*int((nf+2)/2) * (W/nf + 0.18u)'"
nrd="'0.18u / W'" nrs="'0.18u / W'"
sa=0 sb=0 sd=0
model=pfet_05v0
spiceprefix=X
}
C {ipin.sym} 280 -270 0 0 {name=p1 lab=I}
C {opin.sym} 460 -270 0 0 {name=p2 lab=ZN}
C {iopin.sym} 380 -400 3 0 {name=p3 lab=VDD}
C {iopin.sym} 380 -140 1 0 {name=p4 lab=VSS}
C {iopin.sym} 460 -340 0 0 {name=p5 lab=VNW}
C {iopin.sym} 460 -200 0 0 {name=p6 lab=VPW}
