module REG_BANK (
    input [4:0] ReadReg1,
    input [4:0] ReadReg2,
    input [4:0] WrReg,
    input [31:0] WrData,
    input regWrite,

    output reg [31:0] ReadData1,
    output reg [31:0] ReadData2
);

reg [31:0] mem [0:31];

initial begin
	$readmemb("registersData.txt", mem);
end

always @*
begin
    if(regWrite) begin
        mem[WrReg] <= WrData;
    end

    // Read data from registers
    ReadData1 <= mem[ReadReg1];
    ReadData2 <= mem[ReadReg2];
end

endmodule

