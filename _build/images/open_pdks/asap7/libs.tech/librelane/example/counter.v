// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// 8-bit counter with asynchronous reset, LibreLane example for ASAP7

module counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       en,
    output reg  [7:0] count
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            count <= 8'd0;
        else if (en)
            count <= count + 8'd1;
endmodule
