module MEM_WB(
    //*Entradas
    input clk,
    input reset,

    //control para wb
    input regWrite_in, //habilita la escritura en el registro
    input memToReg_in, // elige en el MUX final si se guarda el dato de la RAM (1) o de la ALU (0)

    //datos para wb
    input [31:0]read_data_in, //dato leido de la ram
    input [31:0]alu_result_in, //resultado de la alu
    input [4:0]write_reg_in, //registro destino

    //**Salidas

    output reg regWrite_out,
    output reg memToReg_out,

    output reg [31:0]read_data_out,
    output reg [31:0]alu_result_out,
    output reg [4:0]write_reg_out
);

 always @(posedge clk or posedge reset) begin 
        if(reset) begin 
            regWrite_out    <= 1'b0;
            memToReg_out    <= 1'b0;
            read_data_out   <= 32'b0;
            alu_result_out  <= 32'b0;
            write_reg_out   <= 5'b0;
        end else begin
            regWrite_out   <= regWrite_in;
            memToReg_out   <= memToReg_in;
            read_data_out  <= read_data_in;
            alu_result_out <= alu_result_in;
            write_reg_out  <= write_reg_in;
        end
    end

endmodule