module line_buffer #(
  parameter integer W=256, C=16, KH=3, P_C=4
)(
  input wire clk, input wire rst_n, input wire i_valid,
  input wire signed [7:0] i_data [0:P_C-1], input wire [$clog2(W)-1:0] i_col,
  output reg o_valid, output reg signed [7:0] o_window [0:P_C*KH-1]
);
  integer index;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin o_valid <= 1'b0; for (index=0; index<P_C*KH; index=index+1) o_window[index] <= '0; end
    else begin o_valid <= i_valid; if (i_valid) for (index=0; index<P_C*KH; index=index+1) o_window[index] <= '0; end
  end
endmodule
