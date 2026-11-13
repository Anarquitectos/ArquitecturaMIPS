module ALU_CONTROL(
    input [5:0] funct, // para tipo R, tipo I no lo usa
    input [2:0] ALUOp, // indica el tipo de operacion, lo indica control_unit
    output reg [3:0] ALUctl // el codigo que va a recibir la ALU
);

always @* begin
    case(ALUOp)
        3'b00: ALUctl <= 4'b0010; // add for lw/sw
        3'b01: ALUctl <= 4'b0110; // sub for branch
        3'b10: begin // R-type instructions: listen to funct field 
            case(funct)
                6'b100000: ALUctl <= 4'b0010; // add
                6'b100001: ALUctl = 4'b0010; // addu
                6'b100010: ALUctl <= 4'b0110; // sub
                6'b100011: ALUctl = 4'b0110; // subu
                6'b100100: ALUctl <= 4'b0000; // and
                6'b100101: ALUctl <= 4'b0001; // or
                6'b101010: ALUctl <= 4'b0111; // slt
                6'b100110: ALUctl = 4'b0011; // xor
                6'b100111: ALUctl = 4'b1100; // nor
                default:   ALUctl <= 4'b0000;
            endcase
        end
        // operaciones para instrucciones inmediatas
        3'b011: ALUctl <= 4'b0111; // slti -> set on less than
        3'b100: ALUctl <= 4'b0000; // andi -> AND
        3'b101: ALUctl <= 4'b0001; // ori  -> OR
        3'b110: ALUctl <= 4'b0011; // xori -> XOR
        3'b111: ALUctl <= 4'b1000; // lui  -> desplazar 16 bits
        default: ALUctl <= 4'b0000;
    endcase
end

endmodule
