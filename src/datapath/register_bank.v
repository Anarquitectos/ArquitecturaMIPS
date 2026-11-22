module REG_BANK (
    input clk,
    input [4:0] ReadReg1, // rs
    input [4:0] ReadReg2, // rt
    input [4:0] WrReg, // rt o rd, donde escribir
    input [31:0] WrData, // dato a escribir
    input regWrite, // si es 1 se puede escribir

    output reg [31:0] ReadData1, // 
    output reg [31:0] ReadData2
);

reg [31:0] mem [0:31];

initial begin
	$readmemb("registersData.txt", mem);
end

always @* // en flanco de subida
begin
    // si lo pongo dentro del always hay problema de retraso con la instruccion tipo I
    assign ReadData1 = mem[ReadReg1];
    assign ReadData2 = mem[ReadReg2];

end

always @* begin
    if(regWrite && WrReg != 5'd0) begin
        mem[WrReg] = WrData;
    end
end

endmodule

