module RAM ( // sincrona
	input clk,
	input [5:0]DirL,
	input we, // si es 1, puede escribir
	input [31:0]DataIn,
	output reg[31:0]DataOut
);

reg [31:0]mem[0:63];

// escritura combinacional, cada que cambia, modifica
assign DataOut = mem[DirL]; 

always @(posedge clk)
begin
	if(we)
	begin // escribir
		mem[DirL]<=DataIn;
	end
end

initial begin
	$readmemb("memram.txt",mem);
end


endmodule
