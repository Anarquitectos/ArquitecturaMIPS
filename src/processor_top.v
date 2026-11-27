module PROCESSOR_MIPS
(
    input clk,
    input reset,

    //* DEBUG en la DE10-Lite
    input [4:0] debug_reg_addr,
    input [5:0] debug_mem_addr,
    output [31:0] debug_pc,
    output [31:0] debug_inst,
    output [31:0] debug_alu,
    output [31:0] debug_reg_data,
    output [31:0] debug_mem_data
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


// ROM o Memoria de instrucciones
wire [31:0] instruction;

ROM instruction_memory(
    .insAddress(pc_out),
    .ins(instruction)
);

//Buffer 
wire [31:0] pc_ID, im_out_ID; // reciben las salidas del buffer

IF_ID if_id_buffer(
    .clk(clk),
    .reset(reset),
    .pc_in(pc_incremented), //conecta a la salida del sumador pc adder
    .im_in(instruction), //conecta la salida de la rom
    .pc_out(pc_ID),
    .im_out(im_out_ID) //conecta las salidad del buffer
);

// Jump
wire [31:0] jump_shift_in; // entrada
// pipeline: usa instruccion y PC guardados en IF/ID
assign jump_shift_in = {6'b0,im_out_ID[25:0]}; // entrada concatenada para completar los 32 bits
wire [31:0] jump_shift_out; // salida

// instancia para desplazar 2 bits de jump para la concatenacion con pc 
ShiftLeft Jump_shift(
    .input32(jump_shift_in),
    .output32Shift2(jump_shift_out)
);

// une los 4 bits de pc con los 28 bits ya desplazados
wire [31:0] jump_address; 
assign jump_address = {pc_ID[31:28], jump_shift_out[27:0]}; // pipeline: usa instruccion y PC guardados en IF/ID

// Unidad de control
wire regDst, aluSrc, memToReg, regWrite, memRead, memWrite, branch, extOp, jump;
wire [2:0] aluOp;

CONTROL_UNIT control_unit(
    .opcode(im_out_ID[31:26]),  // pipeline: decodifica la instruccion que sale de IF/ID
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

// Register Bank
wire [31:0] read_data1, read_data2;
wire [31:0] write_back_data;

wire regWrite_WB;
wire [4:0] write_reg_WB;

REG_BANK register_bank(
    .clk(clk),
    .reset(reset),
    .ReadReg1(im_out_ID[25:21]),  //? rs pipeline: lee rs y rt de la instruccion en IF/ID
    .ReadReg2(im_out_ID[20:16]),  // ?rt
    .WrReg(write_reg_WB),          // ?cambie esto registro destino que regresa desde MEM/WB 
    .WrData(write_back_data),       // dato final de la alu o ram
    .regWrite(regWrite_WB & ~reset),   //? protege contra escritura cuando hay reset
    .ReadData1(read_data1),
    .ReadData2(read_data2),
    .DebugReg(debug_reg_addr),
    .DebugData(debug_reg_data)
);

// Inmediato de 16 bits -> 32 bits Sign Extend
wire [31:0] sign_ext;

SIGN_EXT sign_extend(
    .bin16(im_out_ID[15:0]),  // pipeline: extiende el inmediato de la instruccion en IF/ID
    .opExt(extOp),              // 1 = signo, 0 = ceros
    .bin32(sign_ext)
);

//EX

// Cables de salida del buffer ID/EX
wire regWrite_EX, memToReg_EX, branch_EX, memRead_EX, memWrite_EX, regDst_EX, aluSrc_EX;
wire [2:0] aluOp_EX;
wire [31:0] pc_EX, read_data1_EX, read_data2_EX, sign_ext_EX;
wire [4:0] rt_EX, rd_EX;

ID_EX id_ex_buffer (

    //**entradas 
    //todas las señales vienen de control unit:
    .clk(clk),
    .reset(reset),
    .regWrite_in(regWrite), 
    .memToReg_in(memToReg), 
    .branch_in(branch), 
    .memRead_in(memRead), 
    .memWrite_in(memWrite), 
    .regDst_in(regDst), 
    .aluSrc_in(aluSrc), 
    .aluOp_in(aluOp),

    //entrada de datos

    .pc_in(pc_ID), // viene del primer buffer, seria el pc+4
    .read_data1_in(read_data1), //rs
    .read_data2_in(read_data2), //rt
    .sign_ext_in(sign_ext), 
    .rt_in(im_out_ID[20:16]), 
    .rd_in(im_out_ID[15:11]),

    //**salidas

    // Control que viaja hasta WB (regWrite, memToReg)

    .regWrite_out(regWrite_EX),
    .memToReg_out(memToReg_EX),

    // Control que viaja hasta MEM (branch, memRead, memWrite)

    .branch_out(branch_EX),
    .memRead_out(memRead_EX),
    .memWrite_out(memWrite_EX),

    // Control y datos que se usan ya mismo en EX (regDst, aluSrc, aluOp, pc, datos y registros)

    .regDst_out(regDst_EX),
    .aluSrc_out(aluSrc_EX),
    .aluOp_out(aluOp_EX),
    .pc_out(pc_EX),
    .read_data1_out(read_data1_EX),
    .read_data2_out(read_data2_EX),
    .sign_ext_out(sign_ext_EX),
    .rt_out(rt_EX),
    .rd_out(rd_EX)
);

// MUX para seleccionar el registro de destino (Instrucciones Tipo R vs Tipo I)
wire [31:0] write_reg_mux;
wire [4:0] write_reg;

// Rellenado de 27 bits con ceros para que el MUX tenga entradas de 32 bits
MUX reg_dst_mux(
    .sel(regDst_EX),
    .A({27'd0, rt_EX}), // rt para instrucciones tipo I
    .B({27'd0, rd_EX}), // rd para instrucciones tipo R
    .S(write_reg_mux)
);
assign write_reg = write_reg_mux[4:0]; // Ignora el relleno de 27 bits y toma solo los 5 bits menos significativos


// Branch: offset x 4
wire [31:0] branch_shift_out; // El offset desplazado a la izquierda por 2 bits (multiplicado por 4)

ShiftLeft branch_shift (
    .input32(sign_ext_EX),                 // offset ya extendido a 32 bits con signo
    .output32Shift2(branch_shift_out)   // offset x4 que entrara en el branch
);

// Sumador para calcular la dirección de salto en caso de branch
wire [31:0] branch_offset; // El resultado del branch adder, que será la nueva dirección de PC si se toma el branch

ADDER branch_adder(
    .A(pc_EX),
    .B(branch_shift_out), // PC + 4 mas el offset x 4
    .res(branch_offset)
);

// ALU Control Unit
wire [3:0] alu_control_signal;

ALU_CONTROL alu_control(
    .funct(sign_ext_EX[5:0]), // Campo funct de la instruccion en Instrucciones tipo R
    .ALUOp(aluOp_EX),
    .ALUctl(alu_control_signal)
);


// ALU Input MUX (seleciona entre el registro rt y el inmediato extendido)
wire [31:0] alu_input_b;

MUX alu_input_mux(
    .sel(aluSrc_EX),
    .A(read_data2_EX),     // Register data
    .B(sign_ext_EX),
    .S(alu_input_b)
);


// ALU
wire [31:0] alu_result;
wire alu_zero_flag;

ALU alu(
    .ALUctl(alu_control_signal),
    .A(read_data1_EX),     // siempre rs
    .B(alu_input_b),
    .ALUOut(alu_result),
    .Zero(alu_zero_flag)
);

// EX_MEM

// Cables de salida del buffer EX/MEM
wire regWrite_MEM, memToReg_MEM, branch_MEM, memRead_MEM, memWrite_MEM, Zero_MEM;
wire [31:0] branch_target_MEM, alu_result_MEM, write_data_MEM;
wire [4:0] write_reg_MEM;


EX_MEM ex_mem_buffer(

    //**entradas

    .clk(clk),
    .reset(reset),

    //control hacia wb
    .regWrite_in(regWrite_EX), 
    .memToReg_in(memToReg_EX),

    //Control hacia MEM:
    .branch_in(branch_EX), 
    .memRead_in(memRead_EX), 
    .memWrite_in(memWrite_EX),

    //datos de ex

    .branch_target_in(branch_offset), //direccion destino del branch
    .Zero_in(alu_zero_flag), //bandera de la ALU (1 si el resultado fue cero)
    .alu_result_in(alu_result), //resultado de la ALU y da la direccion de RAM o el dato calculado
    .write_data_in(read_data2_EX), // dato de rt que se escribira en RAM si es sw
    .write_reg_in(write_reg),

    //**salidas

    .regWrite_out(regWrite_MEM), 
    .memToReg_out(memToReg_MEM), //siguen de largo hasta wb

    .branch_out(branch_MEM), // Control que se usa ahorita en MEM (salto y RAM)
    .memRead_out(memRead_MEM),

    .memWrite_out(memWrite_MEM), // Datos que entran a la RAM, al branch o pasan al ultimo buffer
    .branch_target_out(branch_target_MEM),
    .Zero_out(Zero_MEM), 
    .alu_result_out(alu_result_MEM), 
    
    .write_data_out(write_data_MEM),
    .write_reg_out(write_reg_MEM)
);

// MUX para seleccionar la entrada del PC (branching, jumping, etc.)
wire branch_AND;
assign branch_AND = branch_MEM & Zero_MEM;

// salida para conectar pc mux a jump mux 
wire [31:0] branch_or_next;


MUX pc_mux(
    .sel(branch_AND),
    .A(pc_incremented),
    .B(branch_target_MEM),
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
    .reset(reset),
    .DirL(alu_result_MEM[7:2]), // direccion en bytes / 4 = indice de palabra
    .we(memWrite_MEM & ~reset), //? protege contra escritura cuando hay reset
    .DataIn(write_data_MEM),    // sw guarda el valor de rt
    .DataOut(mem_read_data),
    .DebugAddr(debug_mem_addr),
    .DebugData(debug_mem_data)
);

// Cables de salida del buffer MEM/WB
wire memToReg_WB;
wire [31:0] read_data_WB, alu_result_WB;

MEM_WB mem_wb_buffer(
    .clk(clk),
    .reset(reset),

    // Control hacia WB (vienen de EX/MEM)
    .regWrite_in(regWrite_MEM),
    .memToReg_in(memToReg_MEM),

    // Datos hacia WB
    .read_data_in(mem_read_data),     // dato leído de la RAM
    .alu_result_in(alu_result_MEM),   // resultado de la ALU que venía pasando
    .write_reg_in(write_reg_MEM),     // registro destino elegido en EX

    // Salidas hacia la etapa final Write Back
    .regWrite_out(regWrite_WB),
    .memToReg_out(memToReg_WB),
    .read_data_out(read_data_WB),
    .alu_result_out(alu_result_WB),
    .write_reg_out(write_reg_WB)
);

// MUX para seleccionar el dato a escribir de vuelta en el banco de registros (de ALU o RAM)
MUX write_data_mux(
    .sel(memToReg_WB),
    .A(alu_result_WB),     // Dato proveniente de la ALU
    .B(read_data_WB),  // Dato proveniente de la RAM
    .S(write_back_data)
);

assign debug_pc   = pc_out;
assign debug_inst = instruction;
assign debug_alu  = alu_result;

endmodule
