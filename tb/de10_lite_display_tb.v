`timescale 1ns/1ps

module de10_lite_display_tb;
    reg clk;
    reg [9:0] switches;
    wire [9:0] leds;
    wire [6:0] hex0;
    wire [6:0] hex1;
    wire [6:0] hex2;
    wire [6:0] hex3;
    wire [6:0] hex4;
    wire [6:0] hex5;
    integer i;

    integer cpu_ticks;
    integer ticks_when_paused;

    de10_lite_top #(
        .CLOCK_DIVIDER_COUNT(4)
    ) dut (
        .MAX10_CLK1_50(clk),
        .SW(switches),
        .LEDR(leds),
        .HEX0(hex0),
        .HEX1(hex1),
        .HEX2(hex2),
        .HEX3(hex3),
        .HEX4(hex4),
        .HEX5(hex5)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    always @(posedge dut.cpu_clk)
        cpu_ticks = cpu_ticks + 1;

    initial begin
        cpu_ticks = 0;
        switches = 10'b1000000000;
        #2;
        for (i = 0; i < 17; i = i + 1)
            dut.cpu.data_memory.mem[18 + i] = 32'd0;
        dut.cpu.data_memory.mem[18] = 32'd72;  // H
        dut.cpu.data_memory.mem[19] = 32'd79;  // O
        dut.cpu.data_memory.mem[20] = 32'd76;  // L
        dut.cpu.data_memory.mem[21] = 32'd65;  // A

        #25 switches[9] = 1'b0;
        switches[0] = 1'b1;
        wait (cpu_ticks >= 2);
        switches[0] = 1'b0;
        ticks_when_paused = cpu_ticks;
        repeat (8) @(posedge clk);
        if (cpu_ticks != ticks_when_paused) begin
            $display("FAIL: el procesador no se pauso al bajar SW0.");
            $finish;
        end
        $display("PASS: reloj automatico activo con SW0 y pausado al desactivarlo.");

        force dut.pc_val = 32'd40;
        force dut.inst_val = {6'b000010, 26'd7};

        wait (dut.result_done === 1'b1);
        repeat (20) @(posedge clk);
        #1;

        if (!dut.result_ready || dut.result_length != 5'd4 ||
            dut.result_text[0] != 8'd72 ||
            dut.result_text[1] != 8'd79 ||
            dut.result_text[2] != 8'd76 ||
            dut.result_text[3] != 8'd65 ||
            leds[8] !== 1'b1) begin
            $display("FAIL: el wrapper no capturo correctamente el texto desde RAM.");
            $finish;
        end

        switches[3:1] = 3'b101;
        #1;
        if (hex5 !== 7'b0001001 ||
            hex4 !== 7'b0100011 ||
            hex3 !== 7'b1000111 ||
            hex2 !== 7'b0001000) begin
            $display("FAIL: los displays no muestran correctamente HOLA.");
            $finish;
        end

        $display("PASS: resultado capturado y visible en el display del wrapper.");
        $finish;
    end
endmodule
