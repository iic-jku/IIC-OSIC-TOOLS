v {xschem version=3.0.0 file_version=1.2 }
G {}
K {}
V {}
S {}
E {}
N 720 -800 720 -760 { lab=VSS}
N 720 -1020 720 -980 { lab=VDD}
N 720 -950 790 -950 { lab=VDD}
N 790 -1020 790 -950 { lab=VDD}
N 720 -830 790 -830 { lab=VSS}
N 790 -830 790 -760 { lab=VSS}
N 720 -890 720 -860 { lab=out}
N 660 -950 680 -950 { lab=in}
N 660 -890 660 -830 { lab=in}
N 660 -830 680 -830 { lab=in}
N 720 -890 880 -890 { lab=out}
N 720 -1020 790 -1020 { lab=VDD}
N 720 -760 790 -760 { lab=VSS}
N 660 -950 660 -890 { lab=in}
N 720 -920 720 -890 { lab=out}
N 560 -760 720 -760 { lab=VSS}
N 560 -890 660 -890 { lab=in}
N 560 -1020 720 -1020 { lab=VDD}
C {devices/ipin.sym} 560 -890 0 0 {name=p1 lab=in}
C {devices/opin.sym} 880 -890 0 0 {name=p2 lab=out
}
C {devices/ipin.sym} 560 -1020 0 0 {name=p3 lab=VDD
}
C {devices/ipin.sym} 560 -760 0 0 {name=p4 lab=VSS}
C {sky130_fd_pr/pfet_g5v0d10v5.sym} 700 -950 0 0 {name=M10

L=0.5
W=8
nf=2 mult=1
model=pfet_g5v0d10v5
spiceprefix=X
}
C {sky130_fd_pr/nfet_g5v0d10v5.sym} 700 -830 0 0 {name=M9

L=0.5
W=2
nf=1 mult=1
model=nfet_g5v0d10v5
spiceprefix=X
}
