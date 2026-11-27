module de10_lite_top #(
    parameter CLOCK_DIVIDER_COUNT = 250_000
)(
    input        MAX10_CLK1_50, // Reloj interno de 50 MHz de la DE10-Lite (PIN_P11)
    input  [9:0] SW,
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);
    wire reset          = SW[9];   // Switch 9 = Reset (1 = reinicia PC y Registros a 0)
    wire [2:0] view_sel = SW[3:1]; // Switches 3..1 = Qué señal ver en los displays
    wire [4:0] reg_sel  = SW[8:4]; // Switches 8..4 = Qué registro (R0-R31) inspeccionar
    localparam RESULT_START_WORD = 6'd18;
    localparam RESULT_MAX_CHARS = 17;
    localparam TEXT_VIEW = 3'b101;
    localparam COMPLETION_MARKER_ADDR = 6'd63;
    localparam [31:0] COMPLETION_MARKER = 32'h00005A5A;

    // SW[0] habilita el avance automatico; cada flanco ascendente ejecuta una instruccion.
    reg [31:0] clock_divider = 32'd0;
    reg cpu_clk = 1'b0;

    always @(posedge MAX10_CLK1_50 or posedge reset) begin
        if (reset) begin
            clock_divider <= 32'd0;
            cpu_clk <= 1'b0;
        end else if (!SW[0]) begin
            clock_divider <= 32'd0;
            cpu_clk <= 1'b0;
        end else if (clock_divider == CLOCK_DIVIDER_COUNT - 1) begin
            clock_divider <= 32'd0;
            cpu_clk <= ~cpu_clk;
        end else begin
            clock_divider <= clock_divider + 32'd1;
        end
    end

    wire [31:0] pc_val, inst_val, alu_val, reg_val;
    wire [31:0] result_mem_data;
    wire [5:0] result_mem_addr;
    wire program_finished;
    reg result_done;
    reg result_ready;
    reg [4:0] result_scan_index;
    reg [4:0] result_length;
    reg [4:0] scroll_start;
    reg [24:0] scroll_counter;
    reg [7:0] result_text [0:RESULT_MAX_CHARS-1];
    reg [7:0] display_chars [0:5];
    integer reset_index;
    integer display_index;

    PROCESSOR_MIPS cpu (
        .clk(cpu_clk),
        .reset(reset),
        .debug_reg_addr(reg_sel),
        .debug_mem_addr(result_mem_addr),
        .debug_pc(pc_val),
        .debug_inst(inst_val),
        .debug_alu(alu_val),
        .debug_reg_data(reg_val),
        .debug_mem_data(result_mem_data)
    );

    assign result_mem_addr = result_done
        ? RESULT_START_WORD + result_scan_index
        : COMPLETION_MARKER_ADDR;
    assign program_finished = (result_mem_data == COMPLETION_MARKER);

    always @(posedge MAX10_CLK1_50) begin
        if (reset) begin
            result_done <= 1'b0;
            result_ready <= 1'b0;
            result_scan_index <= 5'd0;
            result_length <= RESULT_MAX_CHARS;
            scroll_start <= 5'd0;
            scroll_counter <= 25'd0;
            for (reset_index = 0; reset_index < RESULT_MAX_CHARS; reset_index = reset_index + 1)
                result_text[reset_index] <= 8'd0;
        end else begin
            if (program_finished)
                result_done <= 1'b1;

            if (result_done && !result_ready) begin
                result_text[result_scan_index] <= result_mem_data[7:0];
                if (result_mem_data[7:0] == 8'd0 &&
                    result_length == RESULT_MAX_CHARS)
                    result_length <= result_scan_index;

                if (result_scan_index == RESULT_MAX_CHARS - 1) begin
                    result_scan_index <= 5'd0;
                    result_ready <= 1'b1;
                end else begin
                    result_scan_index <= result_scan_index + 5'd1;
                end
            end

            if (result_ready) begin
                if (scroll_counter == 25'd99_999_999) begin
                    scroll_counter <= 25'd0;
                    if (result_length > 5'd6 &&
                        scroll_start < result_length - 5'd6)
                        scroll_start <= scroll_start + 5'd1;
                    else
                        scroll_start <= 5'd0;
                end else begin
                    scroll_counter <= scroll_counter + 25'd1;
                end
            end else begin
                scroll_counter <= 25'd0;
                scroll_start <= 5'd0;
            end
        end
    end

    // LEDR8 indica que el resultado fue capturado; LEDR7:0 muestran el PC.
    assign LEDR[9]   = reset;
    assign LEDR[8]   = result_ready;
    assign LEDR[7:0] = pc_val[7:0];

    // view_sel=101 muestra el texto resultante; las otras opciones conservan la depuración.
    reg [23:0] display_data;
    always @* begin
        case (view_sel)
            3'b000: display_data = {pc_val[7:0], inst_val[15:0]}; // HEX5-4: PC | HEX3-0: Inst baja
            3'b001: display_data = inst_val[23:0];                // Instrucción (24 bits bajos)
            3'b010: display_data = {8'h00, inst_val[31:16]};      // Opcode/Registros (16 bits altos)
            3'b011: display_data = alu_val[23:0];                 // Resultado de la ALU
            3'b100: display_data = reg_val[23:0];                 // Valor del Registro elegido en SW[8:4]
            3'b101: display_data = 24'd0;
            default: display_data = {pc_val[7:0], alu_val[15:0]}; // PC + ALU baja
        endcase
    end

    always @* begin
        for (display_index = 0; display_index < 6; display_index = display_index + 1) begin
            if (result_ready && scroll_start + display_index < result_length)
                display_chars[display_index] = result_text[scroll_start + display_index];
            else
                display_chars[display_index] = 8'h20;
        end
    end

    wire [6:0] hex_seg0, hex_seg1, hex_seg2, hex_seg3, hex_seg4, hex_seg5;
    wire [6:0] text_seg0, text_seg1, text_seg2, text_seg3, text_seg4, text_seg5;
    wire show_result = (view_sel == TEXT_VIEW);

    seg7_hex d0 (.hex(display_data[3:0]),   .seg(hex_seg0));
    seg7_hex d1 (.hex(display_data[7:4]),   .seg(hex_seg1));
    seg7_hex d2 (.hex(display_data[11:8]),  .seg(hex_seg2));
    seg7_hex d3 (.hex(display_data[15:12]), .seg(hex_seg3));
    seg7_hex d4 (.hex(display_data[19:16]), .seg(hex_seg4));
    seg7_hex d5 (.hex(display_data[23:20]), .seg(hex_seg5));

    seg7_ascii t0 (.ascii(display_chars[5]), .seg(text_seg0));
    seg7_ascii t1 (.ascii(display_chars[4]), .seg(text_seg1));
    seg7_ascii t2 (.ascii(display_chars[3]), .seg(text_seg2));
    seg7_ascii t3 (.ascii(display_chars[2]), .seg(text_seg3));
    seg7_ascii t4 (.ascii(display_chars[1]), .seg(text_seg4));
    seg7_ascii t5 (.ascii(display_chars[0]), .seg(text_seg5));

    assign HEX0 = show_result ? text_seg0 : hex_seg0;
    assign HEX1 = show_result ? text_seg1 : hex_seg1;
    assign HEX2 = show_result ? text_seg2 : hex_seg2;
    assign HEX3 = show_result ? text_seg3 : hex_seg3;
    assign HEX4 = show_result ? text_seg4 : hex_seg4;
    assign HEX5 = show_result ? text_seg5 : hex_seg5;

endmodule

module seg7_ascii (
    input [7:0] ascii,
    output reg [6:0] seg
);
    always @* begin
        case (ascii)
            8'h30: seg = 7'b1000000; // 0
            8'h31: seg = 7'b1111001; // 1
            8'h32, 8'h5A, 8'h7A: seg = 7'b0100100; // 2, Z/z
            8'h33: seg = 7'b0110000; // 3
            8'h34: seg = 7'b0011001; // 4
            8'h35, 8'h53, 8'h73: seg = 7'b0010010; // 5, S/s
            8'h36: seg = 7'b0000010; // 6
            8'h37: seg = 7'b1111000; // 7
            8'h38: seg = 7'b0000000; // 8
            8'h39: seg = 7'b0010000; // 9
            8'h41, 8'h61: seg = 7'b0001000; // A/a
            8'h42, 8'h62: seg = 7'b0000011; // b
            8'h43, 8'h63: seg = 7'b1000110; // C/c
            8'h44, 8'h64: seg = 7'b0100001; // d
            8'h45, 8'h65: seg = 7'b0000110; // E/e
            8'h46, 8'h66: seg = 7'b0001110; // F/f
            8'h47, 8'h67: seg = 7'b1000010; // G/g
            8'h48, 8'h68, 8'h4B, 8'h6B, 8'h58, 8'h78: seg = 7'b0001001; // H/h, K/k, X/x
            8'h49, 8'h69: seg = 7'b1111001; // I/i
            8'h4A, 8'h6A: seg = 7'b1100001; // J/j
            8'h4C, 8'h6C: seg = 7'b1000111; // L/l
            8'h4D, 8'h6D, 8'h4E, 8'h6E: seg = 7'b0101011; // m, n
            8'h4F, 8'h6F, 8'h51, 8'h71: seg = 7'b0100011; // o, q
            8'h50, 8'h70: seg = 7'b0001100; // P/p
            8'h52, 8'h72: seg = 7'b0101111; // r
            8'h54, 8'h74: seg = 7'b0000111; // t
            8'h55, 8'h75, 8'h56, 8'h76, 8'h57, 8'h77: seg = 7'b1000001; // U/u, V/v, W/w
            8'h59, 8'h79: seg = 7'b0010001; // Y/y
            8'h20: seg = 7'b1111111; // espacio
            8'h2D: seg = 7'b0111111; // guion
            default: seg = 7'b1111111;
        endcase
    end
endmodule

// Decodificador 7 segmentos para DE10-Lite (0 = encendido, 1 = apagado)
module seg7_hex (
    input  [3:0] hex,
    output reg [6:0] seg
);
    always @* begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end
endmodule