module ALU(
	input [3:0]ALUctl,
	input [31:0]A,
	input [31:0]B, // este ahora puede ser rt o el inmediato, según ALUSrc
	output reg [31:0]ALUOut,
	output Zero	
);

assign Zero = (ALUOut==0);
always @*
	begin
		case(ALUctl)
			4'd0: ALUOut <= A & B; // AND
			4'd1: ALUOut <= A | B; // OR
			4'd2: ALUOut <= A + B; // ADD
			4'd3: ALUOut <= A ^ B; // XOR
			4'd6: ALUOut <= A - B; // SUB
			4'd7: ALUOut <= $signed(A) < $signed(B) ? 32'd1 : 32'd0; // SLT con signo
			4'd8: ALUOut <= B << 16; // LUI
			4'd12: ALUOut <= ~(A | B); // NOR
			default: ALUOut <= 0; // Default case
		endcase
	end

endmodule  