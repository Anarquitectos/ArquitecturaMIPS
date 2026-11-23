module de10_lite_top (
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

    // Filtro antirrebote (20 ms a 50 MHz) para que SW[0] genere un pulso limpio por movimiento
    reg [19:0] db_cnt = 20'd0;
    reg clk_clean = 1'b0;

    always @(posedge MAX10_CLK1_50) begin
        if (SW[0] != clk_clean) begin
            db_cnt <= db_cnt + 20'd1;
            if (db_cnt == 20'd1_000_000) begin
                clk_clean <= SW[0];
                db_cnt <= 20'd0;
            end
        end else begin
            db_cnt <= 20'd0;
        end
    end

    wire [31:0] pc_val, inst_val, alu_val, reg_val;

    PROCESSOR_MIPS cpu (
        .clk(clk_clean),           // Se conecta el reloj filtrado en lugar de SW[0] directo
        .reset(reset),
        .debug_reg_addr(reg_sel),
        .debug_pc(pc_val),
        .debug_inst(inst_val),
        .debug_alu(alu_val),
        .debug_reg_data(reg_val)
    );

    // LEDs superiores muestran el estado del reset, reloj limpio y el PC actual en binario
    assign LEDR[9]   = reset;
    assign LEDR[8]   = clk_clean;
    assign LEDR[7:0] = pc_val[7:0];

    // Multiplexor para elegir qué mostrar en los 6 displays HEX (24 bits = 6 dígitos hex)
    reg [23:0] display_data;
    always @* begin
        case (view_sel)
            3'b000: display_data = {pc_val[7:0], inst_val[15:0]}; // HEX5-4: PC | HEX3-0: Inst baja
            3'b001: display_data = inst_val[23:0];                // Instrucción (24 bits bajos)
            3'b010: display_data = {8'h00, inst_val[31:16]};      // Opcode/Registros (16 bits altos)
            3'b011: display_data = alu_val[23:0];                 // Resultado de la ALU
            3'b100: display_data = reg_val[23:0];                 // Valor del Registro elegido en SW[8:4]
            default: display_data = {pc_val[7:0], alu_val[15:0]}; // PC + ALU baja
        endcase
    end

    // Instancias de decodificadores Hexadecimal -> 7 Segmentos (activo en bajo)
    seg7_hex d0 (.hex(display_data[3:0]),   .seg(HEX0));
    seg7_hex d1 (.hex(display_data[7:4]),   .seg(HEX1));
    seg7_hex d2 (.hex(display_data[11:8]),  .seg(HEX2));
    seg7_hex d3 (.hex(display_data[15:12]), .seg(HEX3));
    seg7_hex d4 (.hex(display_data[19:16]), .seg(HEX4));
    seg7_hex d5 (.hex(display_data[23:20]), .seg(HEX5));

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