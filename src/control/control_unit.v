module CONTROL_UNIT (
    input [5:0] opcode,     // 6-bit opcode from instruction

    output reg RegDst,      // register destination select
    output reg Branch,      // branch enable for AND with Zero flag
    output reg MemRead,     // memory read enable
    output reg MemtoReg,    // memory to bank register
    output reg [2:0] ALUOp, // 3-bit ALU operation code
    output reg MemWrite,    // memory write enable
    output reg ALUSrc,      // alu source select
    output reg RegWrite,    // bank register write enable
    output reg ExtOp
);

always @* begin
    // valores predeterminados
    RegDst    = 0;
    Branch    = 0;
    MemRead   = 0;
    MemtoReg  = 0;
    ALUOp     = 3'b000;
    MemWrite  = 0;
    ALUSrc    = 0;
    RegWrite  = 0;
    ExtOp     = 1;
    case(opcode)
        6'b000000: begin        // R-type instructions
            RegDst   <= 1;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 1;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b10;  // R-type ALU operation
        end
        6'b100011: begin        // lw instruction
            RegDst   <= 0;
            ALUSrc   <= 1;
            MemtoReg <= 1;
            RegWrite <= 1;
            MemRead  <= 1;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // lw ALU operation (add)
        end
        6'b101011: begin        // sw instruction
            RegDst   <= 'bx;    // not relevant
            ALUSrc   <= 1;
            MemtoReg <= 'bx;    // not relevant
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 1;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // sw ALU operation (add)
        end
        6'b000100: begin        // branch instruction
            RegDst   <= 'bx;    // not relevant
            ALUSrc   <= 0;
            MemtoReg <= 'bx;    // not relevant
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 1;      // enable branch
            ALUOp    <= 3'b01;  // beq ALU operation (sub)
        end
        default: begin          // default case for unsupported opcodes
            RegDst   <= 0;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // default ALU operation (add)
        end
    // para tipo I 
        6'b001000,          // para addi
        6'b001001: begin    // para addiu
        // GPR[rt] <= GPR[rs] + immediate (para addi y addiu)
            ALUSrc = 1; 
            RegWrite = 1; // lo va a guardar en rt
            ALUOp = 3'b000; 
            ExtOp = 1; 
        end
        6'b001010: begin  // slti, compara rs con inmediato
        // GPR[rt] <= (GPR[rs] < sign_extend(immediate) )
            ALUSrc = 1; // para que pase el inmediato y no rt
            RegWrite = 1;  // lo va a guardar en rt
            ALUOp = 3'b011; // slti
            ExtOp = 1; 
        end
        6'b001100: begin 
        // GPR[rt] <= GPR[rs] and zero_extend(immediate)
            ALUSrc = 1; // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b100; 
            ExtOp = 0; 
        end
        6'b001101: begin // or con el inmediato extendido con CEROS
        // GPR[rt] <= GPR[rs] or zero_extend(immediate)
            ALUSrc = 1; 
            RegWrite = 1; 
            ALUOp = 3'b101; 
            ExtOp = 0; 
        end

        // xori: XOR con el inmediato extendido con CEROS
        6'b001110: begin 
        // GPR[rt] <= GPR[rs] xor zero_extend(immediate)
            ALUSrc = 1; // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b110; // xor
            ExtOp = 0; 
        end

        // lui: carga el inmediato en los 16 bits altos
        6'b001111: begin 
        //GPR[rt] <= immediate || 0^16
            ALUSrc = 1; // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b111; 
            ExtOp = 0; 
        end

    endcase
end

endmodule
