`timescale 1ns/1ps

module type_i_monocycle_tb;
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
        $readmemb("instrucciones_tipoI.txt", dut.instruction_memory.mem);
        for (i = 0; i < 32; i = i + 1) dut.register_bank.mem[i] = 32'd0;
        for (i = 0; i < 64; i = i + 1) dut.data_memory.mem[i]   = 32'd0;

        #11 reset = 1'b0;            // t = 12 ns

        repeat (9) @(posedge clk);   // 9 instrucciones = 9 flancos
        #1;

        check_register(5'd0, 32'h00000000);
        check_register(5'd1, 32'd6);          // addi $1,$1,1
        check_register(5'd2, 32'hFFFFFFFD);   // addi con inmediato negativo
        check_register(5'd3, 32'h000000FD);   // andi con ceros
        check_register(5'd4, 32'h00000F05);   // ori
        check_register(5'd5, 32'd1);          // slti con signo
        check_register(5'd6, 32'h12340000);   // lui
        check_register(5'd7, 32'd5);          // lw

        if (dut.data_memory.mem[1] !== 32'd5) begin
            $display("ERROR: RAM[1] = %h, esperado 5", dut.data_memory.mem[1]);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: instrucciones tipo I, lw y sw correctos.");
        else
            $display("FAIL: %0d verificaciones fallaron.", errors);

        $stop;
    end
endmodule