/*
* counter_tb.v -- Simple Digital Counter Example Testbench in Verilog
*
* (c) 2021-2025 Harald Pretl (harald.pretl@jku.at)
* Johannes Kepler University Linz, Institute for Integrated Circuits
*/

`timescale 1ns / 1ns

`include "counter.v"

module counter_tb;

  // Make a reset that pulses once
  reg reset = 1'b0;
  initial begin
    #17 reset = 1'b1;
    #11 reset = 1'b0;
    #29 reset = 1'b1;
    #11 reset = 1'b0;
    #200 $finish; // this stops the simulation
  end

  // Make a regular pulsing clock
  reg clk = 1'b0;
  always #5 clk = ~clk;

  wire [3:0] value;
  
  // Instantiate the counter module and assign ports
  counter #(.WIDTH(4)) counter1 (
	  .o_out(value),
	  .i_clk(clk),
	  .i_reset(reset)
  );

  initial begin
     $dumpfile("counter_tb.vcd");
     $dumpvars(1, counter_tb);
     $monitor("At time %t, value = %h (%0d)", $time, value, value);
  end

endmodule // counter_tb

