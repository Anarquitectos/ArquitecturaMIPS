module ROM(
    input  [31:0] insAddress,
    output [31:0] ins
);
    reg [7:0] mem [0:255];

    // Concatena los 4 bytes de la memoria para formar la instrucción de 32 bits
    // Endianess: Little Endian (least significant byte first)
    assign ins = {mem[insAddress + 3], mem[insAddress + 2], mem[insAddress + 1], mem[insAddress]};

    initial begin
        // Carga de instrucciones desde un archivo de texto
        $readmemb("instrucciones.txt", mem);
    end
endmodule
