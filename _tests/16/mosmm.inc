// Mismatch model of NMOS and PMOS
//   w, l, m    ... MOS parameters
//   vtmm, u0mm ... normalized mismatch (+1 means +1 sigma)

subckt submodn(drain gate source bulk) 
  parameters w=1u l=1u $mfactor=1 vtmm=0 u0mm=0
  parameters sqrtarea=sqrt(w*l*$mfactor)
  parameters vvt=vtmm*(5e-3*1e-6/sqrtarea/sqrt(2))
  parameters vu0r=u0mm*(1.04e-2*1e-6/sqrtarea/sqrt(2))
  // This simple model may exhibit discontinuity or even exceed limits on channel length
  vgmm (gate gate_int) vsource dc=vvt
  m0 (drain gate_int source bulk) nmosmod w=w*(1+vu0r) l=l $mfactor=$mfactor ad=w*0.18u as=w*0.18u pd=2*(w+0.18u) ps=2*(w+0.18u) nrs=0.18u/w nrd=0.18u/w
ends

subckt submodp(drain gate source bulk) 
  parameters w=1u l=1u $mfactor=1 vtmm=0 u0mm=0
  parameters sqrtarea=sqrt(w*l*$mfactor)
  parameters vvt=vtmm*(5.49e-3*1e-6/sqrtarea/sqrt(2))
  parameters vu0r=u0mm*(0.99e-2*1e-6/sqrtarea/sqrt(2))
  // This simple model may exhibit discontinuity or even exceed limits on channel length
  vgmm (gate gate_int) vsource dc=vvt
  m0 (drain gate_int source bulk) pmosmod w=w*(1+vu0r) l=l $mfactor=$mfactor ad=w*0.18u as=w*0.18u pd=2*(w+0.18u) ps=2*(w+0.18u) nrs=0.18u/w nrd=0.18u/w
ends

