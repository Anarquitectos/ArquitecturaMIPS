module RAM (
	input [5:0]DirL,
	input we,
	input [31:0]DataIn,
	output reg[31:0]DataOut
);

reg [31:0]mem[0:63];

always @*
begin
	if(we)
	begin // escribir
		mem[DirL]<=DataIn;
	end
	else // leer
	begin
		DataOut <= mem[DirL];
	end
end

initial begin
	$readmemb("memram.txt",mem);
end


endmodule
