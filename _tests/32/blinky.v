// SPDX-FileCopyrightText: 2026 Harald Pretl
// Johannes Kepler University, Department for Integrated Circuits
// SPDX-License-Identifier: Apache-2.0
//
// Smallest design that still needs a clock, a flip-flop chain and an output
// pin, so every stage of a place-and-route flow has something to do.

module blinky (input clk, output led);
	reg [23:0] cnt = 0;
	always @(posedge clk) cnt <= cnt + 1'b1;
	assign led = cnt[23];
endmodule
