module EX_MEM(
    //***Entradas****
    //sincronizadores para el buffer
    input clk,
    input reset,

    //para la etapa wb que siguen de paso hasta el final
    input regWrite_in,
    input memToReg_in,

    //para la etapa mem (se usan justo al salir del buffer )

    input branch_in,
    input memRead_in,
    input memWrite_in,

    // datos que vienen de los modulos execute

    input [31:0]branch_target_in, //resultado del sumador branch adder, que regresera al pc mux si se cumple el salto
    input Zero_in,     //bandera que saca alu la cual se combinara con el branch en la compuerta and
    input [31:0]alu_result_in, //servira como direccion de la ram en lw/ sw o como dato final en ins i/j
    input [31:0]write_data_in, //el valor rt que pasaria directo y se guardara en la ram si la instruccion es sw
    input [4:0]write_reg_in, //destino ya elegido por el MUX y que viajara hasta wb para escribir en el banco de registros


    //**salidas

    // Pasan de largo hacia el siguiente buffer MEM/WB
    output reg regWrite_out,
    output reg memToReg_out,

    // Controlan la RAM y el salto en esta etapa MEM
    output reg branch_out,
    output reg memRead_out,
    output reg memWrite_out,

    // Resultados de EX que entran a la RAM, al branch o pasan a MEM/WB
    output reg [31:0] branch_target_out,
    output reg Zero_out,
    output reg [31:0]alu_result_out,
    output reg [31:0]write_data_out,
    output reg [4:0]write_reg_out

);
   always @(posedge clk or posedge reset) begin
        if(reset) begin  
        
        regWrite_out        <= 1'b0;           
        memToReg_out        <= 1'b0;            
        branch_out          <= 1'b0;             
        memRead_out         <= 1'b0;             
        memWrite_out        <= 1'b0;            
        branch_target_out   <= 32'b0;
        Zero_out            <= 1'b0;                
        alu_result_out      <= 32'b0;    
        write_data_out      <= 32'b0;    
        write_reg_out       <= 5'b0;      
        
            end else begin 

            regWrite_out     <= regWrite_in;  
            memToReg_out     <= memToReg_in;
            branch_out       <= branch_in;
            memRead_out      <= memRead_in;
            memWrite_out     <= memWrite_in;
            branch_target_out<= branch_target_in;
            Zero_out         <= Zero_in;
            alu_result_out   <= alu_result_in;
            write_data_out   <= write_data_in;
            write_reg_out    <= write_reg_in;

                end
    end

endmodule    