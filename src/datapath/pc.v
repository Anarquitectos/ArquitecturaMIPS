module PC(
    input clk,
    input reset,
    input [31:0] nextPC,
    output reg [31:0] currentPC
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            currentPC <= 32'b0; // Reset en 0
        end else begin
            currentPC <= nextPC; // Actualiza el PC con la siguiente dirección
        end
    end

endmodule
