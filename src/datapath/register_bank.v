module REG_BANK (
    input clk,
    input reset,
    input [4:0] ReadReg1,   // rs
    input [4:0] ReadReg2,   // rt
    input [4:0] WrReg,      // rt o rd, donde escribir
    input [31:0] WrData,    // dato a escribir
    input regWrite,         // si es 1 se puede escribir

    output [31:0] ReadData1,
    output [31:0] ReadData2,

    // Puertos extras para inspeccionar registros en los displays de la DE10-Lite
    input [4:0] DebugReg,
    output [31:0] DebugData
);

reg [31:0] mem [0:31];
integer k;

initial begin
    $readmemb("registersData.txt", mem);
end

// Lectura combinacional (R0 siempre es 0)
assign ReadData1 = (ReadReg1 == 5'd0) ? 32'd0 : mem[ReadReg1];
assign ReadData2 = (ReadReg2 == 5'd0) ? 32'd0 : mem[ReadReg2];
assign DebugData = (DebugReg == 5'd0) ? 32'd0 : mem[DebugReg];

// Escritura síncrona en flanco de subida del reloj
always @(posedge clk) begin
    if (reset) begin
            for (k = 1; k < 32; k = k + 1)
                mem[k] <= 32'd0;
        end else if (regWrite && WrReg != 5'd0) begin
            mem[WrReg] <= WrData;
        end
end

endmodule