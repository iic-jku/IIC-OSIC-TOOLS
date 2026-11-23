// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// Yosys latch map for ICsprout55_SC9T_BASIC_SVT. The install script derives
// the HVT and LVT maps from it by the cell suffix.

module \$_DLATCH_P_ (input E, input D, output Q);
  LATQX1_9TSVT _TECHMAP_DLATCH_P (.CK(E), .D(D), .Q(Q));
endmodule

module \$_DLATCH_N_ (input E, input D, output Q);
  LATNQX1_9TSVT _TECHMAP_DLATCH_N (.CKN(E), .D(D), .Q(Q));
endmodule

module \$_DLATCH_PN0_ (input E, input R, input D, output Q);
  LATRNQX1_9TSVT _TECHMAP_DLATCH_PN0 (.CK(E), .D(D), .RN(R), .Q(Q));
endmodule

module \$_DLATCH_NN0_ (input E, input R, input D, output Q);
  LATNRNQX1_9TSVT _TECHMAP_DLATCH_NN0 (.CKN(E), .D(D), .RN(R), .Q(Q));
endmodule

module \$_DLATCH_PN1_ (input E, input R, input D, output Q);
  LATSNQX1_9TSVT _TECHMAP_DLATCH_PN1 (.CK(E), .D(D), .SN(R), .Q(Q));
endmodule

module \$_DLATCH_NN1_ (input E, input R, input D, output Q);
  LATNSNQX1_9TSVT _TECHMAP_DLATCH_NN1 (.CKN(E), .D(D), .SN(R), .Q(Q));
endmodule

module \$_DLATCHSR_PNN_ (input E, input S, input R, input D, output Q);
  LATRSNQX1_9TSVT _TECHMAP_DLATCHSR_PNN (.CK(E), .D(D), .SN(S), .RN(R), .Q(Q));
endmodule

module \$_DLATCHSR_NNN_ (input E, input S, input R, input D, output Q);
  LATNRSNQX1_9TSVT _TECHMAP_DLATCHSR_NNN (.CKN(E), .D(D), .SN(S), .RN(R), .Q(Q));
endmodule
