module ID_EX (
    //***Entradas****
    //sincronizadores para el buffer
    input clk,
    input reset,

    //Señales que vienen de control unit
    input regWrite_in, // (se usan hasta la ultima etapa que es wb
    input memToReg_in, // )

    input branch_in, // ( salto condicional (pasan directo por EX sin usarse)
    input memRead_in, //lectura 
    input memWrite_in, // escritura )

    input regDst_in, // ( estas se usan justo al salir (elige si es rt o rd)
    input aluSrc_in, //elige si alu usa inmediato o registro
    input [2:0] aluOp_in, //le dice a alu control que operadion hacer )

    //Datos que vienen de IF/ID, REG_BANK y SIGN_EXT

    input [31:0] pc_in, //viene de pc id para calcular el salto en EX
    input [31:0] read_data1_in, //valor de registro rs
    input [31:0] read_data2_in, //valor de registro rt
    input [31:0] sign_ext_in, //16 bits extendido a 32
    input [4:0] rt_in, //[20:16] de la instrucción (su destino es tipo i)
    input [4:0] rd_in, // [15:11] de la instruccion destino tipo r
   
   //**SALIDAS (pasan al siguiente buffer)***

    //Salidas de control unit

    output reg regWrite_out,
    output reg memToReg_out,
    output reg branch_out,
    output reg memRead_out,
    output reg memWrite_out,
    output reg regDst_out,
    output reg aluSrc_out,
    output reg [2:0] aluOp_out,

    //Salidas que vienen de IF/ID, REG_BANK y SIGN_EXT

    output reg [31:0] pc_out,
    output reg [31:0] read_data1_out,
    output reg [31:0] read_data2_out,
    output reg [31:0] sign_ext_out,
    output reg [4:0] rt_out,
    output reg [4:0] rd_out
);

always @(posedge clk or posedge reset) begin
    if(reset) begin  
            // se apagan las señales para no escribir basura
            regWrite_out   <= 1'b0;
            memToReg_out   <= 1'b0;
            branch_out     <= 1'b0;  
            memRead_out    <= 1'b0;
            memWrite_out   <= 1'b0;
            regDst_out     <= 1'b0;  
            aluSrc_out     <= 1'b0;  
            aluOp_out      <= 3'b0;

            pc_out         <= 32'b0;        
            read_data1_out <= 32'b0;
            read_data2_out <= 32'b0;
            sign_ext_out   <= 32'b0; 
            rt_out         <= 5'b0;  
            rd_out         <= 5'b0;

        end else begin 
            //Deja pasar todos los id hacia ex
            regWrite_out   <= regWrite_in;
            memToReg_out   <= memToReg_in;
            branch_out     <= branch_in;
            memRead_out    <= memRead_in;
            memWrite_out   <= memWrite_in; 
            regDst_out     <= regDst_in; 
            aluSrc_out     <= aluSrc_in;
            aluOp_out      <= aluOp_in;
                         
            pc_out         <= pc_in;
            read_data1_out <= read_data1_in;
            read_data2_out <= read_data2_in;
            sign_ext_out   <= sign_ext_in;
            rt_out         <= rt_in;
            rd_out         <= rd_in;


        end
    end
endmodule                