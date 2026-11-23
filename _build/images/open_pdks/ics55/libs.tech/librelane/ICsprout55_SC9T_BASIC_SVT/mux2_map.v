// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// Yosys MUX2 map for ICsprout55_SC9T_BASIC_SVT (Y = S ? B : A).

module \$_MUX_ (output Y, input A, input B, input S);
  MX2X1_9TSVT _TECHMAP_MUX (.A(A), .B(B), .S(S), .Y(Y));
endmodule
