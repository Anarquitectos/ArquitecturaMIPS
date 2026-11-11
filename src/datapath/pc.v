module PC(
    input clk,
    input reset,
    input [31:0] nextPC,
    output reg [31:0] currentPC
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            currentPC <= 32'b0; // Reset to 0
        end else begin
            currentPC <= nextPC; // Update PC with nextPC
        end
    end

endmodule
