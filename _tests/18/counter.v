/*
* counter.v -- Simple Digital Counter Example in Verilog
*
* (c) 2021-2025 Harald Pretl (harald.pretl@jku.at)
* Johannes Kepler University Linz, Department for Integrated Circuits
*/

module counter #(parameter WIDTH=32) (
  output reg [WIDTH-1:0] out_o,
  input                  clk_i,
  input	                 reset_i
);

  always @(posedge clk_i or posedge reset_i) begin
    // we use an asynchronous reset
    if (reset_i) begin
      out_o <= {WIDTH{1'b0}};
    end else begin
      out_o <= out_o + {{WIDTH-1{1'b0}},1'b1};
    end
  end

endmodule // counter

