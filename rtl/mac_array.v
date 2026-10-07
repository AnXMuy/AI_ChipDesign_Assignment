module mac_array #(
  parameter integer P_KN=8, P_KH=3, P_KW=3, P_C=4, ACC_WIDTH=32
)(
  input wire clk, input wire rst_n, input wire i_valid,
  input wire signed [7:0] x [0:P_KH*P_KW*P_C-1],
  input wire signed [7:0] wgt [0:P_KN*P_KH*P_KW*P_C-1],
  output reg o_valid,
  output reg signed [ACC_WIDTH-1:0] psum [0:P_KN-1]
);
  integer output_channel, element;
  reg signed [2*8-1:0] product;
  reg signed [ACC_WIDTH-1:0] sum;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin o_valid <= 1'b0; for (output_channel=0; output_channel<P_KN; output_channel=output_channel+1) psum[output_channel] <= '0; end
    else begin
      o_valid <= i_valid;
      if (i_valid) begin
        for (output_channel=0; output_channel<P_KN; output_channel=output_channel+1) begin
          sum = '0;
          for (element=0; element<P_KH*P_KW*P_C; element=element+1) begin
            product = x[element] * wgt[output_channel*P_KH*P_KW*P_C + element];
            sum = sum + product;
          end
          psum[output_channel] <= sum;
        end
      end
    end
  end
endmodule
