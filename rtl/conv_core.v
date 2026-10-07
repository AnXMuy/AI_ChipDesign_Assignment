module conv_core #(parameter integer ACC_WIDTH=32)(input wire clk, input wire rst_n, input wire i_valid, input wire signed [ACC_WIDTH-1:0] i_acc, output wire o_valid, output wire signed [7:0] o_data);
  quantizer #(.ACC_WIDTH(ACC_WIDTH)) u_quant(.clk(clk), .rst_n(rst_n), .i_valid(i_valid), .i_acc(i_acc), .o_valid(o_valid), .o_q(o_data));
endmodule
