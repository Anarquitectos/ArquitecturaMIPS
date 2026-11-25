module IF_ID(
    input clk,
    input reset,
    input [31:0]pc_in, //para recibir pc + 4
    input [31:0]im_in, //para recibir instruciones de memoria

    output reg [31:0] pc_out, //salida del buffer para pc + 4
    output reg [31:0] im_out  //salida del buffer para ins mem 
);

    always @(posedge clk or posedge reset) begin 
        if(reset) begin 
            pc_out <= 32'b0; //al reiniciar no ejecuta ni escribe nada por accidente
            im_out <= 32'b0;
        end else begin
            pc_out <= pc_in; //pc_in es el origen y pc_out es el destino
            im_out <= im_in;
        end
    end
endmodule    
