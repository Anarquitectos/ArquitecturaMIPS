module ROM(
    input  [31:0] insAddress,
    output [31:0] ins
);
    reg [7:0] mem [0:255];

    // Concatenate 4 bytes to form a 32-bit instruction
    // Endianess: Little Endian (least significant byte first)
    assign ins = {mem[insAddress + 3], mem[insAddress + 2], mem[insAddress + 1], mem[insAddress]};

    initial begin
        // Load instructions from file
        $readmemb("instrucciones.txt", mem);
    end
endmodule
