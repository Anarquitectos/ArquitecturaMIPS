`timescale 1ns/1ps

module jump_branch_tb;
    reg clk;
    reg reset;
    integer errors;
    integer i;

    PROCESSOR_MIPS dut (.clk(clk), .reset(reset));

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_register;
        input [4:0]  register_number;
        input [31:0] expected_value;
        begin
            if (dut.register_bank.mem[register_number] !== expected_value) begin
                $display("ERROR: R%0d = %h, esperado %h",
                         register_number,
                         dut.register_bank.mem[register_number],
                         expected_value);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        reset  = 1'b1;

        #1;  // deja que terminen los $readmemb de los modulos
        $readmemb("instrucciones_jump_branch.txt", dut.instruction_memory.mem);
        for (i = 0; i < 32; i = i + 1) dut.register_bank.mem[i] = 32'd0;
        for (i = 0; i < 64; i = i + 1) dut.data_memory.mem[i]   = 32'd0;

        #11 reset = 1'b0;            // t = 12 ns

        // Se ejecutan 8 instrucciones: dir 0, 4, 8, 16, 20, 24, 28, 40
        repeat (8) @(posedge clk);
        #1;

        check_register(5'd1, 32'd5);   // addi
        check_register(5'd2, 32'd5);   // addi
        check_register(5'd3, 32'd0);   // saltada por beq (iguales)
        check_register(5'd4, 32'd7);   // destino del beq
        check_register(5'd5, 32'd3);   // beq NO salta (5 != 7), se ejecuta
        check_register(5'd7, 32'd0);   // saltada por j
        check_register(5'd8, 32'd0);   // saltada por j
        check_register(5'd6, 32'd4);   // destino del j (dir 40)

        if (dut.pc_out !== 32'd44) begin
            $display("ERROR: PC = %0d, esperado 44", dut.pc_out);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: j y beq (salta y no salta) correctos.");
        else
            $display("FAIL: %0d verificaciones fallaron.", errors);

        $stop;
    end
endmodule
