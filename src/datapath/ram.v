module RAM (
	input clk,
	input [5:0]DirL,
	input we, // si es 1, puede escribir
	input [31:0]DataIn,
	output reg[31:0]DataOut
);

reg [31:0]mem[0:63];


always @* begin
	if(we) begin
		mem[DirL]=DataIn;
	end
	assign DataOut = mem[DirL]; 
end

initial begin
	$readmemb("memram.txt",mem);
end


endmodule
