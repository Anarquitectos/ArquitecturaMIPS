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
    output reg ExtOp,
    output reg Jump         // instruccion para indicar salto incondicional
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
    Jump      = 0;
    case(opcode)
        //? Instrucciones Tipo R
        6'b000000: begin        
            RegDst   <= 1;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 1;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b10;  // Operacion de tipo R en ALU (determinado por funct)
        end
        //? Instruccion LW (Load Word)
        6'b100011: begin        
            RegDst   <= 0;
            ALUSrc   <= 1;
            MemtoReg <= 1;
            RegWrite <= 1;
            MemRead  <= 1;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // Operacion de LW en ALU (ADD)
        end
        //? Instruccion SW (Store Word)
        6'b101011: begin        
            RegDst   <= 'bx;    // sin relevancia, no se escribe en banco de registros
            ALUSrc   <= 1;
            MemtoReg <= 'bx;    // sin relevancia, no se escribe en banco de registros
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 1;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // Operacion de SW en ALU (ADD)
        end
        //? BEQ BRANCH instruction
        6'b000100: begin        
            RegDst   <= 'bx;    // sin relevancia, no se escribe en banco de registros
            ALUSrc   <= 0;
            MemtoReg <= 'bx;    // sin relevancia, no se escribe en banco de registros
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 1;      // habilitar branch
            ALUOp    <= 3'b01;  // Operacion de BEQ en ALU (SUB)
        end
        //? Instrucciones tipo I
        6'b001000,              // para addi
        6'b001001: begin        // para addiu
            // GPR[rt] <= GPR[rs] + immediate (para addi y addiu)
            ALUSrc = 1; 
            RegWrite = 1;       // lo va a guardar en rt
            ALUOp = 3'b000; 
            ExtOp = 1; 
        end
        6'b001010: begin        // slti, compara rs con inmediato
            // GPR[rt] <= (GPR[rs] < sign_extend(immediate) )
            ALUSrc = 1;         // para que pase el inmediato y no rt
            RegWrite = 1;       // lo va a guardar en rt
            ALUOp = 3'b011;     // slti
            ExtOp = 1; 
        end
        6'b001100: begin 
            // GPR[rt] <= GPR[rs] and zero_extend(immediate)
            ALUSrc = 1;         // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b100; 
            ExtOp = 0; 
        end
        6'b001101: begin        // or con el inmediato extendido con CEROS
            // GPR[rt] <= GPR[rs] or zero_extend(immediate)
            ALUSrc = 1; 
            RegWrite = 1; 
            ALUOp = 3'b101; 
            ExtOp = 0; 
        end
        6'b001110: begin        // XORI: XOR con el inmediato extendido con CEROS
            // GPR[rt] <= GPR[rs] xor zero_extend(immediate)
            ALUSrc = 1;         // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b110;     // xor
            ExtOp = 0; 
        end
        6'b001111: begin        // LUI: carga el inmediato en los 16 bits altos
            // GPR[rt] <= immediate || 0^16
            ALUSrc = 1;         // para que pase el inmediato
            RegWrite = 1; 
            ALUOp = 3'b111; 
            ExtOp = 0; 
        end
        //? Instrucciones tipo J
        6'b000010: begin
           Jump = 1;            // no se necesita regWrite ni memWrite y tampoco activar el branch 
        end   

        //* Caso por defecto, no se realiza ninguna operación
        default: begin          
            RegDst   <= 0;
            ALUSrc   <= 0;
            MemtoReg <= 0;
            RegWrite <= 0;
            MemRead  <= 0;
            MemWrite <= 0;
            Branch   <= 0;
            ALUOp    <= 3'b00;  // default ALU operation (add)
        end

    endcase
end

endmodule
