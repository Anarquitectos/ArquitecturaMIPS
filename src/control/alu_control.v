module ALU_CONTROL(
    input [5:0] funct,
    input [1:0] ALUOp,
    output reg [3:0] ALUctl
);

always @* begin
    case(ALUOp)
        2'b00: ALUctl <= 4'b0010; // add for lw/sw
        2'b01: ALUctl <= 4'b0110; // sub for branch
        2'b10: begin // R-type instructions: listen to funct field 
            case(funct)
                6'b100000: ALUctl <= 4'b0010; // add
                6'b100010: ALUctl <= 4'b0110; // sub
                6'b100100: ALUctl <= 4'b0000; // and
                6'b100101: ALUctl <= 4'b0001; // or
                6'b101010: ALUctl <= 4'b0111; // slt
                default:   ALUctl <= 4'b0000;
            endcase
        end
        default: ALUctl <= 4'b0000;
    endcase
end

endmodule
