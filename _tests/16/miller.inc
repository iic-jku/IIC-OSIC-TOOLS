// Miller OTA definition

include "mosmm.inc"

// subckt miller(inp inn out vdd vss)
subckt miller(inp inn out vdd vss)
  i0 (vdd net002) isource dc=100u
  xmn3 (net002 net002 vss vss) submodn w=mirr_w  l=mirr_l  $mfactor=1 vtmm=mn3vt u0mm=mn3u0 
  xmn4 (net003 net002 vss vss) submodn w=mirr_wd l=mirr_ld $mfactor=1 vtmm=mn4vt u0mm=mn4u0 
  xmn5 (out net002 vss vss)    submodn w=mirr_wo l=mirr_l  $mfactor=1 vtmm=mn5vt u0mm=mn5u0 
  xmp1 (net005 net005 vdd vdd) submodp w=load_w  l=load_l  $mfactor=1 vtmm=mp1vt u0mm=mp1u0 
  xmp2 (net004 net005 vdd vdd) submodp w=load_w  l=load_l  $mfactor=1 vtmm=mp2vt u0mm=mp2u0 
  xmp3 (out net004 vdd vdd)    submodp w=out_w   l=out_l   $mfactor=2 vtmm=mp3vt u0mm=mp3u0 
  r1 (out net001) resistor r=r_out 
  c1 (net001 net004) capacitor c=c_out 
  xmn1 (net005 inn net003 vss) submodn w=diff_w  l=diff_l  $mfactor=1 vtmm=mn1vt u0mm=mn1u0 
  xmn2 (net004 inp net003 vss) submodn w=diff_w  l=diff_l  $mfactor=1 vtmm=mn2vt u0mm=mn2u0 
ends

