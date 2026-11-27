module RAM (
	input clk,
	input reset,
	input [5:0]DirL,
	input we, // si es 1, puede escribir
	input [31:0]DataIn,
	output [31:0]DataOut,
	input [5:0]DebugAddr,
	output [31:0]DebugData
);

reg [31:0]mem[0:63];
integer k;

assign DataOut = mem[DirL]; 
assign DebugData = mem[DebugAddr];

always @(posedge clk or posedge reset) begin

	if (reset) begin
            for (k = 1; k < 64; k = k + 1)
                mem[k] <= 32'd0;
        end else if(we) begin
		mem[DirL] <= DataIn;
	end
end

initial begin
	$readmemb("memram.txt",mem);
end


endmodule
