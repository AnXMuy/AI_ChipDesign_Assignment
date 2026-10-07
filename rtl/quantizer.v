module quantizer #(parameter integer ACC_WIDTH=32, OUT_WIDTH=8, parameter QUANT_MODE="saturate")(
  input wire clk, input wire rst_n, input wire i_valid,
  input wire signed [ACC_WIDTH-1:0] i_acc,
  output reg o_valid, output reg signed [OUT_WIDTH-1:0] o_q
);
  localparam signed [ACC_WIDTH-1:0] MAX_Q = (1 << (OUT_WIDTH-1)) - 1;
  localparam signed [ACC_WIDTH-1:0] MIN_Q = -(1 << (OUT_WIDTH-1));
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin o_valid <= 1'b0; o_q <= '0; end
    else begin
      o_valid <= i_valid;
      if (i_valid) begin
        if (QUANT_MODE == "truncate") o_q <= i_acc[OUT_WIDTH-1:0];
        else if (i_acc > MAX_Q) o_q <= MAX_Q[OUT_WIDTH-1:0];
        else if (i_acc < MIN_Q) o_q <= MIN_Q[OUT_WIDTH-1:0];
        else o_q <= i_acc[OUT_WIDTH-1:0];
      end
    end
  end
endmodule
