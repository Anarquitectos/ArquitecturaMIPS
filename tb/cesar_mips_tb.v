`timescale 1ns/1ps

// Testbench para probar el programa César generado por assembler/code.py.
// Ejecutar ModelSim desde la carpeta raíz ArquitecturaMIPS, donde están:
// instrucciones.txt, memram.txt y registersData.txt.

module cesar_mips_tb;

    // Para el ejemplo "krod Dodq" descifrado con clave 3:
    // el resultado esperado es "hola Alan", que tiene 9 caracteres.
    localparam integer LEN = 9;
    localparam integer OUTPUT_START_WORD = 18; // Dirección byte 72 / 4

    reg clk;
    reg reset;

    integer i;
    integer errors;
    integer output_writes;
    reg [7:0] expected [0:LEN-1];

    PROCESSOR_MIPS dut (
        .clk(clk),
        .reset(reset),
        .debug_reg_addr(5'd0),
        .debug_pc(),
        .debug_inst(),
        .debug_alu(),
        .debug_reg_data()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Contar únicamente las escrituras de salida en RAM[18] en adelante.
    // Las escrituras de entrada (RAM[0] a RAM[LEN-1]) no se cuentan.
    always @(posedge clk) begin
        if (!reset && dut.memWrite &&
            dut.alu_result[7:2] >= OUTPUT_START_WORD &&
            dut.alu_result[7:2] < OUTPUT_START_WORD + LEN) begin
            output_writes = output_writes + 1;
        end
    end

    task check_output;
        integer j;
        reg [31:0] actual;
        begin
            $display("");
            $display("========== RESULTADO DEL PROGRAMA CESAR ==========");

            for (j = 0; j < LEN; j = j + 1) begin
                actual = dut.data_memory.mem[OUTPUT_START_WORD + j];

                if (actual[7:0] !== expected[j]) begin
                    $display(
                        "FAIL RAM[%0d]: ASCII=%0d ('%c'), esperado ASCII=%0d ('%c')",
                        OUTPUT_START_WORD + j,
                        actual[7:0], actual[7:0],
                        expected[j], expected[j]
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "PASS RAM[%0d]: ASCII=%0d ('%c')",
                        OUTPUT_START_WORD + j,
                        actual[7:0], actual[7:0]
                    );
                end
            end

            if (errors == 0)
                $display("PASS: el resultado en RAM coincide con el texto esperado.");
            else
                $display("FAIL: %0d caracter(es) no coinciden.", errors);

            $display("==================================================");
        end
    endtask

    initial begin
        errors = 0;
        output_writes = 0;
        reset = 1'b1;

        // Texto esperado para descifrar "krod Dodq" con clave 3:
        // "hola Alan". Cambia estos valores si pruebas otro texto.
        expected[0] = 8'd104; // h
        expected[1] = 8'd111; // o
        expected[2] = 8'd108; // l
        expected[3] = 8'd97;  // a
        expected[4] = 8'd32;  // espacio
        expected[5] = 8'd65;  // A
        expected[6] = 8'd108; // l
        expected[7] = 8'd97;  // a
        expected[8] = 8'd110; // n

        // Esperar a que terminen los $readmemb iniciales de ROM/RAM/registros.
        #1;

        // Cargar explícitamente el archivo recién generado por Python.
        // Debe ejecutarse ModelSim desde la raíz del proyecto.
        $readmemb("instrucciones.txt", dut.instruction_memory.mem);

        // El programa generado carga su propia frase y sus constantes.
        // Por eso iniciamos limpios los registros y las 64 palabras de RAM.
        for (i = 0; i < 32; i = i + 1)
            dut.register_bank.mem[i] = 32'd0;

        for (i = 0; i < 64; i = i + 1)
            dut.data_memory.mem[i] = 32'd0;

        // Mantener reset activo y después comenzar ejecución.
        #11 reset = 1'b0;

        $display("Iniciando simulacion del programa Cesar...");
        $display("ROM: instrucciones.txt");
        $display("Se esperan %0d escrituras de salida desde RAM[%0d].",
                 LEN, OUTPUT_START_WORD);

        // Dar tiempo suficiente para cargar la frase y procesar sus LEN caracteres.
        // El programa termina en un bucle infinito; el testbench termina
        // cuando detecta todas las escrituras de salida.
        i = 0;
        while (output_writes < LEN && i < 1000) begin
            @(posedge clk);
            #1;
            i = i + 1;
        end

        if (output_writes < LEN) begin
            $display("FAIL: tiempo agotado. Solo se detectaron %0d de %0d escrituras.",
                     output_writes, LEN);
            $display("Revisa instrucciones.txt, el reset y el contador de programa.");
            $stop;
        end else begin
            check_output();
            $display("Ciclos observados despues de liberar reset: %0d", i);
            $display("PC al finalizar: %0d", dut.pc_out);
            $stop;
        end
    end

endmodule
