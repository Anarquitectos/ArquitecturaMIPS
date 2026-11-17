module PROCESSOR_MIPS
(
    input clk,
    input reset
);

// Contador de programa (PC)
wire [31:0] pc_out, pc_in;

PC program_counter(
    .clk(clk),
    .reset(reset),
    .nextPC(pc_in),
    .currentPC(pc_out)
);


// Sumador para incrementar el PC en 4 (para la siguiente instrucción)
// (+ 4 porque las instrucciones son de 32 bits = 4 bytes)
wire [31:0] pc_incremented;

ADDER pc_adder(
    .A(pc_out),
    .B(32'd4),
    .res(pc_incremented)
);


// Sumador para calcular la dirección de salto en caso de branch
wire [31:0] branch_offset; // El resultado del branch adder, que será la nueva dirección de PC si se toma el branch
wire [31:0] branch_shift_out; // El offset desplazado a la izquierda por 2 bits (multiplicado por 4)

ADDER branch_adder(
    .A(pc_incremented),
    .B(branch_shift_out), // PC + 4 mas el offset x 4
    .res(branch_offset)
);


// ROM o Memoria de instrucciones
wire [31:0] instruction;

ROM instruction_memory(
    .insAddress(pc_out),
    .ins(instruction)
);

// Jump
wire [31:0] jump_shift_in; // entrada
assign jump_shift_in = {6'b0,instruction[25:0]}; // entrada concatenada para completar los 32 bits
wire [31:0] jump_shift_out; // salida

// instancia para desplazar 2 bits de jump para la concatenacion con pc 
ShiftLeft Jump_shift(
    .input32(jump_shift_in),
    .output32Shift2(jump_shift_out)
);

// une los 4 bits de pc con los 28 bits ya desplazados
wire [31:0] jump_address; 
assign jump_address = {pc_incremented[31:28], jump_shift_out[27:0]};

// Unidad de control
wire regDst, aluSrc, memToReg, regWrite, memRead, memWrite, branch, extOp, jump;
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
    .ExtOp(extOp),
    .Jump(jump)
);



// MUX para seleccionar el registro de destino (Instrucciones Tipo R vs Tipo I)
wire [31:0] write_reg_mux;
wire [4:0] write_reg;

// Rellenado de 27 bits con ceros para que el MUX tenga entradas de 32 bits
MUX reg_dst_mux(
    .sel(regDst),
    .A({27'd0, instruction[20:16]}), // rt para instrucciones tipo I
    .B({27'd0, instruction[15:11]}), // rd para instrucciones tipo R
    .S(write_reg_mux)
);
assign write_reg = write_reg_mux[4:0]; // Ignora el relleno de 27 bits y toma solo los 5 bits menos significativos


// Register Bank
wire [31:0] read_data1, read_data2;
wire [31:0] write_back_data;

REG_BANK register_bank(
    .clk(clk),
    .ReadReg1(instruction[25:21]),  // rs
    .ReadReg2(instruction[20:16]),  // rt
    .WrReg(write_reg),              // destino elegido
    .WrData(write_back_data),       // dato final de la alu o ram
    .regWrite(regWrite),            // tal vez poner & ~ reset, para que no escriba cuando haya reset, pero no se
    .ReadData1(read_data1),
    .ReadData2(read_data2)
);

// Inmediato de 16 bits -> 32 bits Sign Extend
wire [31:0] sign_ext;

SIGN_EXT sign_extend(
    .bin16(instruction[15:0]),  // Los 16 bits de la instruccion
    .opExt(extOp),              // 1 = signo, 0 = ceros
    .bin32(sign_ext)
);

// Branch: offset x 4

ShiftLeft branch_shift (
    .input32(sign_ext),                 // offset ya extendido a 32 bits con signo
    .output32Shift2(branch_shift_out)   // offset x4 que entrara en el branch
);

// ALU Control Unit
wire [3:0] alu_control_signal;

ALU_CONTROL alu_control(
    .funct(instruction[5:0]), // Campo funct de la instruccion en Instrucciones tipo R
    .ALUOp(aluOp),
    .ALUctl(alu_control_signal)
);


// ALU Input MUX (seleciona entre el registro rt y el inmediato extendido)
wire [31:0] alu_input_b;

MUX alu_input_mux(
    .sel(aluSrc),
    .A(read_data2),     // Register data
    .B(sign_ext),
    .S(alu_input_b)
);


// ALU
wire [31:0] alu_result;
wire alu_zero_flag;

ALU alu(
    .ALUctl(alu_control_signal),
    .A(read_data1),     // siempre rs
    .B(alu_input_b),
    .ALUOut(alu_result),
    .Zero(alu_zero_flag)
);



// MUX para seleccionar la entrada del PC (branching, jumping, etc.)
wire branch_AND;
assign branch_AND = branch & alu_zero_flag;

// salida para conectar pc mux a jump mux 
wire [31:0] branch_or_next;


MUX pc_mux(
    .sel(branch_AND),
    .A(pc_incremented),
    .B(branch_offset),
    .S(branch_or_next) // modifique su salida a un nuevo mux para determinar si se ejecuta el salto
);



MUX jump_mux(
    .sel(jump),         // verifica si la instruccion es de tipo j
    .A(branch_or_next), // si es 0 sigue su trayecto
    .B(jump_address),   // direccion del salto si es 1 
    .S(pc_in)
);

// RAM
wire [31:0] mem_read_data; // dato leido de la ram

RAM data_memory(
    .clk(clk),
    .DirL(alu_result[7:2]), // direccion en bytes / 4 = indice de palabra
    .we(memWrite),          // tal vez poner & ~ reset, para que no escriba cuando haya reset, pero no se
    .DataIn(read_data2),    // sw guarda el valor de rt
    .DataOut(mem_read_data)
);

// MUX para seleccionar el dato a escribir de vuelta en el banco de registros (de ALU o RAM)
MUX write_data_mux(
    .sel(memToReg),
    .A(alu_result),     // Dato proveniente de la ALU
    .B(mem_read_data),  // Dato proveniente de la RAM
    .S(write_back_data)
);



endmodule
