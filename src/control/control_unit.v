module CONTROL_UNIT (
    input [5:0] opcode,     // 6-bit opcode from instruction

    output reg RegDst,      // register destination select
    output reg Branch,      // branch enable for AND with Zero flag
    output reg MemRead,     // memory read enable
    output reg MemtoReg,    // memory to bank register
    output reg [1:0] ALUOp, // 2-bit ALU operation code
    output reg MemWrite,    // memory write enable
    output reg ALUSrc,      // alu source select
    output reg RegWrite     // bank register write enable
);

always @* begin
    case(opcode)
        6'b000000: begin        // R-type instructions
            RegDst   <= 1;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 1;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 2'b10;  // R-type ALU operation
        end
        6'b100011: begin        // lw instruction
            RegDst   <= 0;
            ALUSrc   <= 1;
            MemtoReg <= 1;
            RegWrite <= 1;
            MemRead  <= 1;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 2'b00;  // lw ALU operation (add)
        end
        6'b101011: begin        // sw instruction
            RegDst   <= 'bx;    // not relevant
            ALUSrc   <= 1;
            MemtoReg <= 'bx;    // not relevant
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 1;
            Branch   <= 0;
            ALUOp    <= 2'b00;  // sw ALU operation (add)
        end
        6'b000100: begin        // branch instruction
            RegDst   <= 'bx;    // not relevant
            ALUSrc   <= 0;
            MemtoReg <= 'bx;    // not relevant
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 1;      // enable branch
            ALUOp    <= 2'b01;  // beq ALU operation (sub)
        end
        default: begin          // default case for unsupported opcodes
            RegDst   <= 0;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 2'b00;  // default ALU operation (add)
        end
    endcase
end

endmodule
