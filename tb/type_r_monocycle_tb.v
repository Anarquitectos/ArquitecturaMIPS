
`timescale 1ns/1ps

module type_r_monocycle_tb;
    reg clk;
    reg reset;
    integer errors;

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
        begin
            if (dut.register_bank.mem[register_number] !== expected_value) begin
                $display("ERROR: R%0d = %h, expected %h",
                         register_number,
                         dut.register_bank.mem[register_number],
                         expected_value);
                errors = errors + 1;
            end
        end
    endtask

    task display_alu;
        input [8*4-1:0] operation;
        begin
            $display("%s: A=%0d B=%0d ALUctl=%b ALUOut=%0d Zero=%b",
                     operation, dut.alu.A, dut.alu.B,
                     dut.alu_control_signal, dut.alu_result,
                     dut.alu_zero_flag);
        end
    endtask

    initial begin
        errors = 0;
        reset = 1'b1;
        #12 reset = 1'b0;

        #1; display_alu("ADD");
        @(posedge clk); #1;
        check_register(5'd3, 32'd13);

        display_alu("SUB");
        @(posedge clk); #1;
        check_register(5'd4, 32'd10);

        display_alu("AND");
        @(posedge clk); #1;
        check_register(5'd5, 32'd8);

        display_alu("OR");
        @(posedge clk); #1;
        check_register(5'd6, 32'd15);

        display_alu("SLT");
        @(posedge clk); #1;
        check_register(5'd7, 32'd1);

        if (errors == 0)
            $display("PASS: type-R instructions executed correctly.");
        else
            $display("FAIL: %0d type-R checks failed.", errors);

        $stop;
    end
endmodule
