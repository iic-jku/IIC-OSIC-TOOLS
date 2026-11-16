// two inverters in series, layout: invchain.gds
module invchain (A, Y, VDD, VSS);
	input A;
	output Y;
	inout VDD;
	inout VSS;
	wire n1;

	sg13g2_inv_1 u1 (.A(A), .Y(n1), .VDD(VDD), .VSS(VSS));
	sg13g2_inv_1 u2 (.A(n1), .Y(Y), .VDD(VDD), .VSS(VSS));
endmodule
