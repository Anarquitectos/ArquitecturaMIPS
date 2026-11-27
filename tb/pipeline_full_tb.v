`timescale 1ns/1ps

module pipeline_full_tb;
    reg clk;
    reg reset;
    reg [4:0] debug_reg_addr;
    wire [31:0] debug_pc;
    wire [31:0] debug_inst;
    wire [31:0] debug_alu;
    wire [31:0] debug_reg_data;

    integer errors;
    integer overlap_cycles;
    integer i;

    PROCESSOR_MIPS dut (
        .clk(clk),
        .reset(reset),
        .debug_reg_addr(debug_reg_addr),
        .debug_mem_addr(6'd0),
        .debug_pc(debug_pc),
        .debug_inst(debug_inst),
        .debug_alu(debug_alu),
        .debug_reg_data(debug_reg_data),
        .debug_mem_data()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function [31:0] r_type;
        input [4:0] rs;
        input [4:0] rt;
        input [4:0] rd;
        input [5:0] funct;
        begin
            r_type = {6'b000000, rs, rt, rd, 5'b00000, funct};
        end
    endfunction

    function [31:0] i_type;
        input [5:0] opcode;
        input [4:0] rs;
        input [4:0] rt;
        input [15:0] immediate;
        begin
            i_type = {opcode, rs, rt, immediate};
        end
    endfunction

    function [31:0] j_type;
        input [25:0] target;
        begin
            j_type = {6'b000010, target};
        end
    endfunction

    task load_instruction;
        input integer word_address;
        input [31:0] instruction_word;
        integer byte_address;
        begin
            byte_address = word_address * 4;
            dut.instruction_memory.mem[byte_address]     = instruction_word[7:0];
            dut.instruction_memory.mem[byte_address + 1] = instruction_word[15:8];
            dut.instruction_memory.mem[byte_address + 2] = instruction_word[23:16];
            dut.instruction_memory.mem[byte_address + 3] = instruction_word[31:24];
        end
    endtask

    task check_register;
        input [4:0] register_number;
        input [31:0] expected_value;
        input [8*24-1:0] test_name;
        begin
            if (dut.register_bank.mem[register_number] !== expected_value) begin
                $display("FAIL %-24s R%0d=%h esperado=%h",
                         test_name, register_number,
                         dut.register_bank.mem[register_number], expected_value);
                errors = errors + 1;
            end else begin
                $display("PASS %-24s R%0d=%h",
                         test_name, register_number,
                         dut.register_bank.mem[register_number]);
            end
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (!reset &&
            debug_inst !== 32'b0 &&
            dut.im_out_ID !== 32'b0 &&
            dut.regWrite_EX &&
            dut.regWrite_MEM &&
            dut.regWrite_WB)
            overlap_cycles = overlap_cycles + 1;
    end

    initial begin
        errors = 0;
        overlap_cycles = 0;
        debug_reg_addr = 5'd0;
        reset = 1'b1;

        #1;
        for (i = 0; i < 1024; i = i + 1)
            dut.instruction_memory.mem[i] = 8'b0;
        for (i = 0; i < 64; i = i + 1)
            dut.data_memory.mem[i] = 32'b0;

        // Continuous independent operations fill IF, ID, EX, MEM, and WB.
        load_instruction(0,  r_type(5'd1, 5'd2, 5'd3,  6'b100000)); // add
        load_instruction(1,  r_type(5'd1, 5'd2, 5'd4,  6'b100001)); // addu
        load_instruction(2,  r_type(5'd1, 5'd2, 5'd5,  6'b100010)); // sub
        load_instruction(3,  r_type(5'd1, 5'd2, 5'd6,  6'b100011)); // subu
        load_instruction(4,  r_type(5'd1, 5'd2, 5'd7,  6'b100100)); // and
        load_instruction(5,  r_type(5'd1, 5'd2, 5'd8,  6'b100101)); // or
        load_instruction(6,  r_type(5'd1, 5'd2, 5'd9,  6'b100110)); // xor
        load_instruction(7,  r_type(5'd1, 5'd2, 5'd10, 6'b100111)); // nor
        load_instruction(8,  r_type(5'd2, 5'd1, 5'd11, 6'b101010)); // slt
        load_instruction(9,  i_type(6'b001000, 5'd1, 5'd12, 16'hFFFD)); // addi
        load_instruction(10, i_type(6'b001001, 5'd1, 5'd13, 16'hFFFD)); // addiu
        load_instruction(11, i_type(6'b001010, 5'd1, 5'd14, 16'd20)); // slti
        load_instruction(12, i_type(6'b001100, 5'd1, 5'd15, 16'h000B)); // andi
        load_instruction(13, i_type(6'b001101, 5'd1, 5'd16, 16'h0100)); // ori
        load_instruction(14, i_type(6'b001110, 5'd1, 5'd17, 16'h000A)); // xori
        load_instruction(15, i_type(6'b001111, 5'd0, 5'd18, 16'h1234)); // lui
        load_instruction(16, i_type(6'b101011, 5'd0, 5'd1, 16'd0)); // sw
        load_instruction(17, i_type(6'b100011, 5'd0, 5'd19, 16'd0)); // lw
        load_instruction(18, i_type(6'b000100, 5'd1, 5'd2, 16'd2)); // beq not taken
        load_instruction(19, i_type(6'b001000, 5'd0, 5'd20, 16'd20));
        load_instruction(20, i_type(6'b001000, 5'd0, 5'd21, 16'd21));
        load_instruction(21, i_type(6'b000100, 5'd1, 5'd1, 16'd4)); // beq taken to 26
        load_instruction(22, i_type(6'b001000, 5'd0, 5'd22, 16'd22)); // branch delay slot
        load_instruction(23, i_type(6'b001000, 5'd0, 5'd23, 16'd23)); // branch delay slot
        load_instruction(24, i_type(6'b001000, 5'd0, 5'd24, 16'd24)); // branch delay slot
        load_instruction(25, i_type(6'b001000, 5'd0, 5'd29, 16'd99)); // skipped
        load_instruction(26, i_type(6'b001000, 5'd0, 5'd25, 16'd25)); // branch target
        load_instruction(27, j_type(26'd30)); // jump to word 30
        load_instruction(28, i_type(6'b001000, 5'd0, 5'd26, 16'd26)); // jump delay slot
        load_instruction(29, i_type(6'b001000, 5'd0, 5'd27, 16'd88)); // skipped
        load_instruction(30, i_type(6'b001000, 5'd0, 5'd28, 16'd28)); // jump target

        // Reset the sequential state, then seed stable operands for this test.
        #11 reset = 1'b0;
        #1;
        dut.register_bank.mem[1] = 32'd15;
        dut.register_bank.mem[2] = 32'd10;
        dut.data_memory.mem[0] = 32'd0;

        repeat (40) @(posedge clk);
        #2;

        check_register(5'd3,  32'd25,        "ADD");
        check_register(5'd4,  32'd25,        "ADDU");
        check_register(5'd5,  32'd5,         "SUB");
        check_register(5'd6,  32'd5,         "SUBU");
        check_register(5'd7,  32'd10,        "AND");
        check_register(5'd8,  32'd15,        "OR");
        check_register(5'd9,  32'd5,         "XOR");
        check_register(5'd10, 32'hFFFFFFF0,  "NOR");
        check_register(5'd11, 32'd1,         "SLT");
        check_register(5'd12, 32'd12,        "ADDI sign extend");
        check_register(5'd13, 32'd12,        "ADDIU sign extend");
        check_register(5'd14, 32'd1,         "SLTI");
        check_register(5'd15, 32'd11,        "ANDI");
        check_register(5'd16, 32'd271,       "ORI");
        check_register(5'd17, 32'd5,         "XORI");
        check_register(5'd18, 32'h12340000,  "LUI");
        check_register(5'd19, 32'd15,        "LW");
        check_register(5'd20, 32'd20,        "BEQ not taken");
        check_register(5'd21, 32'd21,        "BEQ not taken slot");
        check_register(5'd22, 32'd22,        "BEQ delay slot 1");
        check_register(5'd23, 32'd23,        "BEQ delay slot 2");
        check_register(5'd24, 32'd24,        "BEQ delay slot 3");
        check_register(5'd25, 32'd25,        "BEQ target");
        check_register(5'd29, 32'd0,         "BEQ skipped");
        check_register(5'd26, 32'd26,        "J delay slot");
        check_register(5'd27, 32'd0,         "J skipped");
        check_register(5'd28, 32'd28,        "J target");

        if (dut.data_memory.mem[0] !== 32'd15) begin
            $display("FAIL SW RAM[0]=%h esperado=0000000f", dut.data_memory.mem[0]);
            errors = errors + 1;
        end else begin
            $display("PASS SW RAM[0]=%h", dut.data_memory.mem[0]);
        end

        if (overlap_cycles < 5) begin
            $display("FAIL pipeline: solo %0d ciclos con actividad simultanea en IF/ID/EX/MEM/WB",
                     overlap_cycles);
            errors = errors + 1;
        end else begin
            $display("PASS pipeline: %0d ciclos con actividad simultanea en IF/ID/EX/MEM/WB",
                     overlap_cycles);
        end

        reset = 1'b1;
        for (i = 0; i < 1024; i = i + 1)
            dut.instruction_memory.mem[i] = 8'b0;

        // Verify RAW padding, BEQ/J delay slots, and J-target loop padding.
        load_instruction(0,  i_type(6'b001000, 5'd0, 5'd1, 16'd5));
        load_instruction(1,  32'd0);
        load_instruction(2,  32'd0);
        load_instruction(3,  32'd0);
        load_instruction(4,  i_type(6'b001000, 5'd1, 5'd2, 16'd1));
        load_instruction(5,  32'd0);
        load_instruction(6,  32'd0);
        load_instruction(7,  32'd0);
        load_instruction(8,  i_type(6'b000100, 5'd1, 5'd1, 16'd4));
        load_instruction(9,  32'd0);
        load_instruction(10, 32'd0);
        load_instruction(11, 32'd0);
        load_instruction(12, i_type(6'b001000, 5'd0, 5'd5, 16'd99));
        load_instruction(13, i_type(6'b001000, 5'd2, 5'd3, 16'd1));
        load_instruction(14, j_type(26'd18));
        load_instruction(15, 32'd0);
        load_instruction(16, i_type(6'b001000, 5'd0, 5'd6, 16'd99));
        load_instruction(17, 32'd0);
        load_instruction(18, 32'd0);
        load_instruction(19, 32'd0);
        load_instruction(20, 32'd0);
        load_instruction(21, i_type(6'b001000, 5'd3, 5'd4, 16'd1));
        load_instruction(22, j_type(26'd22));

        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        repeat (35) @(posedge clk);
        #2;

        check_register(5'd1, 32'd5, "RAW producer");
        check_register(5'd2, 32'd6, "RAW consumer");
        check_register(5'd3, 32'd7, "BEQ target");
        check_register(5'd4, 32'd8, "J target");
        check_register(5'd5, 32'd0, "BEQ flush path");
        check_register(5'd6, 32'd0, "J flush path");

        if (errors == 0)
            $display("PASS: instrucciones, hazards de datos, saltos y pipeline verificados.");
        else
            $display("FAIL: %0d verificaciones fallaron.", errors);
        $finish;
    end
endmodule
