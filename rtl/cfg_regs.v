module cfg_regs(
  input wire clk, input wire rst_n, input wire wr_en,
  input wire [7:0] wr_addr, input wire [31:0] wr_data,
  output reg [15:0] cfg_stride, cfg_pad, cfg_h, cfg_w, cfg_c, cfg_kn, cfg_kh, cfg_kw, cfg_kc,
  output reg [1:0] cfg_quant_mode
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin cfg_stride<=1; cfg_pad<=1; cfg_h<=0; cfg_w<=0; cfg_c<=0; cfg_kn<=0; cfg_kh<=3; cfg_kw<=3; cfg_kc<=0; cfg_quant_mode<=0; end
    else if (wr_en) begin
      case (wr_addr)
        8'h00: cfg_stride <= wr_data[15:0];
        8'h04: cfg_pad <= wr_data[15:0];
        8'h08: cfg_h <= wr_data[15:0];
        8'h0c: cfg_w <= wr_data[15:0];
        8'h10: cfg_c <= wr_data[15:0];
        8'h14: cfg_kn <= wr_data[15:0];
        8'h18: cfg_kh <= wr_data[15:0];
        8'h1c: cfg_kw <= wr_data[15:0];
        8'h20: cfg_kc <= wr_data[15:0];
        8'h24: cfg_quant_mode <= wr_data[1:0];
        default: ;
      endcase
    end
  end
endmodule
