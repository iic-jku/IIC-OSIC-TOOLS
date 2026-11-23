// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// Yosys tristate buffer map for ICsprout55_SC9T_BASIC_SVT (OE active high).

module \$_TBUF_ (input A, input E, output Y);
  TBUFX1_9TSVT _TECHMAP_TBUF (.A(A), .OE(E), .Y(Y));
endmodule
