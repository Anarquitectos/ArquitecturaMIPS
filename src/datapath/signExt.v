module SIGN_EXT(
    input[15:0] bin16,
    input opExt, // opcion para saber si se agregara 
    output[31:0] bin32
);

assign bin32 = opExt ? {{16{bin16[15]}}, bin16} : {16'b0, bin16};

endmodule