module PROCESSOR_MIPS
(
    input clk,
    input reset
);

// Program Counter
wire [31:0] pc_out, pc_in;

PC program_counter(
    .clk(clk),
    .reset(reset),
    .nextPC(pc_in),
    .currentPC(pc_out)
);


// Adder to increment PC by 4 for the next instruction
// (+ 4 because each instruction is 4 bytes long)
wire [31:0] pc_incremented;

ADDER pc_adder(
    .A(pc_out),
    .B(32'd4), // Increment by 4 for the next instruction
    .res(pc_incremented)
);


// Adder to calculate the branch offset
wire [31:0] branch_offset; // This will hold the branch offset value

ADDER branch_adder(
    .A(pc_incremented),
    .B(32'd0), // TODO: Implement branch offset calculation
    .res(branch_offset) // This will be the new PC value if a branch is taken
);


// Instruction Memory ROM
wire [31:0] instruction;

ROM instruction_memory(
    .insAddress(pc_out),
    .ins(instruction)
);


// Control Unit
wire regDst, aluSrc, memToReg, regWrite, memRead, memWrite, branch, extOp;
wire [2:0] aluOp;

CONTROL_UNIT control_unit(
    .opcode(instruction[31:26]),
    .RegDst(regDst),
    .Branch(branch),
    .MemRead(memRead),
    .MemtoReg(memToReg),
    .ALUOp(aluOp),
    .MemWrite(memWrite),
    .ALUSrc(aluSrc),
    .RegWrite(regWrite),
    .ExtOp(extOp)
);


// MUX for selecting the destination register (for R-type vs I-type instructions)
wire [31:0] write_reg_mux;
wire [4:0] write_reg;

MUX reg_dst_mux(
    .sel(regDst),
    .A({27'd0, instruction[20:16]}), // rt for I-type instructions
    .B({27'd0, instruction[15:11]}), // rd for R-type instructions
    .S(write_reg_mux)
);
assign write_reg = write_reg_mux[4:0];


// Register Bank
wire [31:0] read_data1, read_data2;
wire [31:0] write_back_data;

REG_BANK register_bank(
    .clk(clk),
    .ReadReg1(instruction[25:21]), // rs
    .ReadReg2(instruction[20:16]), // rt
    .WrReg(write_reg), // destino elegido
    .WrData(write_back_data), // dato final de la alu o ram
    .regWrite(regWrite), // tal vez poner & ~ reset, para que no escriba cuando haya reset, pero no se
    .ReadData1(read_data1),
    .ReadData2(read_data2)
);

// Inmediato de 16 bits -> 32 bits Sign Extend
wire [31:0] sign_ext;

SIGN_EXT sign_extend(
    .bin16(instruction[15:0]), // Los 16 bits de la instruccion
    .opExt(extOp), // 1 = signo, 0 = ceros
    .bin32(sign_ext)
);

// ALU Control Unit
wire [3:0] alu_control_signal;

ALU_CONTROL alu_control(
    .funct(instruction[5:0]), // funct field for R-type instructions
    .ALUOp(aluOp),
    .ALUctl(alu_control_signal)
);


// ALU Input MUX (for selecting between register data and immediate value)
wire [31:0] alu_input_b;

MUX alu_input_mux(
    .sel(aluSrc),
    .A(read_data2), // Register data
    .B(sign_ext), // TODO: Connect to the immediate value (for I-type instructions)
    .S(alu_input_b)
);


// ALU
wire [31:0] alu_result;
wire alu_zero_flag;

ALU alu(
    .ALUctl(alu_control_signal),
    .A(read_data1), // siempre rs
    .B(alu_input_b), // TODO: Connect to the second operand (could be immediate value for I-type), puede ser rt o inmediato
    .ALUOut(alu_result),
    .Zero(alu_zero_flag)
);


// MUX for PC input selection (for branching, jumping, etc.)
wire branch_AND;
assign branch_AND = branch & alu_zero_flag;

MUX pc_mux(
    .sel(branch_AND),
    .A(pc_incremented),
    .B(branch_offset),
    .S(pc_in)
);

// RAM
wire [31:0] mem_read_data; // dato leido de la ram

RAM data_memory(
    .clk(clk),
    .DirL(alu_result[7:2]), // direccion en bytes / 4 = indice de palabra
    .we(memWrite), // tal vez poner & ~ reset, para que no escriba cuando haya reset, pero no se
    .DataIn(read_data2), // sw guarda el valor de rt
    .DataOut(mem_read_data)
);

// MUX for selecting the data to write back to the register bank (from ALU or memory)
MUX write_data_mux(
    .sel(memToReg),
    .A(alu_result), // Data from ALU
    .B(mem_read_data), // TODO: Connect to data read from memory
    .S(write_back_data)
);

endmodule
