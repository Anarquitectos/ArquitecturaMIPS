`timescale 1ns/1ps

module all_instructions_tb;
    reg clk;
    reg reset;
    integer errors;
    integer i;
    integer cycle;

    PROCESSOR_MIPS dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_register;
        input [4:0] register_number;
        input [31:0] expected_value;
        input [8*24-1:0] instruction_name;
        begin
            if (dut.register_bank.mem[register_number] !== expected_value) begin
                $display("FAIL  %-24s R%0d=%h esperado=%h",
                         instruction_name,
                         register_number,
                         dut.register_bank.mem[register_number],
                         expected_value);
                errors = errors + 1;
            end else begin
                $display("PASS  %-24s R%0d=%h",
                         instruction_name,
                         register_number,
                         dut.register_bank.mem[register_number]);
            end
        end
    endtask

    initial begin
        errors = 0;
        cycle = 0;
        reset = 1'b1;

        #1;
        $readmemb("instrucciones_completas.txt", dut.instruction_memory.mem);
        for (i = 0; i < 32; i = i + 1)
            dut.register_bank.mem[i] = 32'd0;
        for (i = 0; i < 64; i = i + 1)
            dut.data_memory.mem[i] = 32'd0;

        #11 reset = 1'b0;

        repeat (32) begin
            @(posedge clk);
            #1;
            cycle = cycle + 1;
            $display("CICLO %0d  PC=%0d  IR=%h  ALU=%h",
                     cycle,
                     dut.pc_out,
                     dut.instruction,
                     dut.alu_result);
        end

        check_register(5'd1,  32'd10,     "ADDI");
        check_register(5'd2,  32'hFFFFFFFD, "ADDIU");
        check_register(5'd3,  32'd7,      "ADD");
        check_register(5'd4,  32'd7,      "ADDU");
        check_register(5'd5,  32'd13,     "SUB");
        check_register(5'd6,  32'd13,     "SUBU");
        check_register(5'd7,  32'd8,      "AND");
        check_register(5'd8,  32'hFFFFFFFF, "OR");
        check_register(5'd11, 32'd1,      "SLT");
        check_register(5'd12, 32'd20,     "BEQ no tomado");
        check_register(5'd13, 32'd0,      "BEQ tomado (skip)");
        check_register(5'd14, 32'd240,    "ORI");
        check_register(5'd15, 32'd15,     "XORI");
        check_register(5'd18, 32'd25,     "J destino");
        check_register(5'd16, 32'h12340000, "LUI");
        check_register(5'd19, 32'd100,    "LW");

        if (errors == 0)
            $display("PASS: todas las instrucciones implementadas fueron probadas.");
        else
            $display("FAIL: %0d verificaciones fallaron.", errors);

        $stop;
    end
endmodule
