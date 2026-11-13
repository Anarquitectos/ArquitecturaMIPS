module ShiftLeft(
    input [31:0] input32,
    output [31:0] output32Shift2
);

assign output32Shift2 = {input32[29:0], 2'b00};

endmodule