module RAM (
	input clk,
	input [5:0]DirL,
	input we, // si es 1, puede escribir
	input [31:0]DataIn,
	output [31:0]DataOut
);

reg [31:0]mem[0:63];

assign DataOut = mem[DirL]; 

always @(posedge clk) begin
	if(we) begin
		mem[DirL] <= DataIn;
	end
end

initial begin
	$readmemb("memram.txt",mem);
end


endmodule
