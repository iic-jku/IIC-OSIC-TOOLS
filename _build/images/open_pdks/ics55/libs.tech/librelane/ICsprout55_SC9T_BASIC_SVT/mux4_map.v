// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// Yosys MUX4 map for ICsprout55_SC9T_BASIC_SVT (S selects within a pair,
// T between the pairs, as S0 and S1 of the cell).

module \$_MUX4_ (output Y, input A, input B, input C, input D, input S, input T);
  MX4X1_9TSVT _TECHMAP_MUX4 (.A(A), .B(B), .C(C), .D(D), .S0(S), .S1(T), .Y(Y));
endmodule
