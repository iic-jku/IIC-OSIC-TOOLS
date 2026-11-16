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
N 380 -400 380 -370 {lab=VPWR}
N 380 -170 380 -140 {lab=VGND}
N 380 -340 460 -340 {lab=VPB}
N 380 -200 460 -200 {lab=VNB}
C {sky130_fd_pr/nfet_01v8.sym} 360 -200 0 0 {name=M1
W=0.65
L=0.15
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=nfet_01v8
spiceprefix=X
}
C {sky130_fd_pr/pfet_01v8_hvt.sym} 360 -340 0 0 {name=M2
W=1
L=0.15
nf=1
mult=1
ad="expr('int((@nf + 1)/2) * @W / @nf * 0.29')"
pd="expr('2*int((@nf + 1)/2) * (@W / @nf + 0.29)')"
as="expr('int((@nf + 2)/2) * @W / @nf * 0.29')"
ps="expr('2*int((@nf + 2)/2) * (@W / @nf + 0.29)')"
nrd="expr('0.29 / @W ')" nrs="expr('0.29 / @W ')"
sa=0 sb=0 sd=0
model=pfet_01v8_hvt
spiceprefix=X
}
C {ipin.sym} 280 -270 0 0 {name=p1 lab=A}
C {opin.sym} 460 -270 0 0 {name=p2 lab=Y}
C {iopin.sym} 380 -400 3 0 {name=p3 lab=VPWR}
C {iopin.sym} 380 -140 1 0 {name=p4 lab=VGND}
C {iopin.sym} 460 -340 0 0 {name=p5 lab=VPB}
C {iopin.sym} 460 -200 0 0 {name=p6 lab=VNB}
