module conv_top #(
  parameter integer MAX_H=256, MAX_W=256, MAX_C=16, MAX_KN=32,
  parameter integer MAX_KH=5, MAX_KW=5, ACC_WIDTH=32,
  parameter integer OUT_WIDTH=8
)(
  input wire clk, input wire rst_n,
  input wire start,
  input wire [15:0] cfg_h, cfg_w, cfg_c, cfg_kn, cfg_kh, cfg_kw,
  input wire [15:0] cfg_stride, cfg_pad,
  input wire [1:0] cfg_quant_mode,
  input wire signed [7:0] input_data,
  input wire input_valid, output wire input_ready,
  input wire signed [7:0] weight_data,
  input wire weight_valid, output wire weight_ready,
  output reg signed [7:0] output_data,
  output reg output_valid, input wire output_ready,
  output reg busy, output reg done
);
  localparam integer INPUT_CAP = MAX_H*MAX_W*MAX_C;
  localparam integer WEIGHT_CAP = MAX_KN*MAX_KH*MAX_KW*MAX_C;
  localparam integer OUTPUT_CAP = MAX_H*MAX_W*MAX_KN;
  reg signed [7:0] input_mem [0:INPUT_CAP-1];
  reg signed [7:0] weight_mem [0:WEIGHT_CAP-1];
  reg signed [7:0] output_mem [0:OUTPUT_CAP-1];
  reg signed [ACC_WIDTH-1:0] acc;
  reg [31:0] input_count, weight_count, output_count;
  reg [31:0] oy, ox, oc, ky, kx, ic;
  reg [3:0] state;
  integer iy, ix, input_index, weight_index;
  localparam S_IDLE=0, S_LOAD_X=1, S_LOAD_W=2, S_CALC=3, S_EMIT=4;

  assign input_ready = (state == S_LOAD_X);
  assign weight_ready = (state == S_LOAD_W);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE; busy <= 0; done <= 0; output_valid <= 0; output_data <= 0;
      input_count <= 0; weight_count <= 0; output_count <= 0; oy<=0; ox<=0; oc<=0; ky<=0; kx<=0; ic<=0; acc<='0;
    end else begin
      done <= 0;
      case (state)
        S_IDLE: begin
          output_valid <= 0;
          if (start) begin state <= S_LOAD_X; busy <= 1; input_count <= 0; weight_count <= 0; output_count <= 0; end
        end
        S_LOAD_X: begin
          if (input_valid && input_ready) begin input_mem[input_count] <= input_data; input_count <= input_count + 1; if (input_count + 1 >= cfg_h*cfg_w*cfg_c) state <= S_LOAD_W; end
        end
        S_LOAD_W: begin
          if (weight_valid && weight_ready) begin weight_mem[weight_count] <= weight_data; weight_count <= weight_count + 1; if (weight_count + 1 >= cfg_kn*cfg_kh*cfg_kw*cfg_c) begin state <= S_CALC; oy<=0; ox<=0; oc<=0; ky<=0; kx<=0; ic<=0; acc<='0; end end
        end
        S_CALC: begin
          iy = oy*cfg_stride + ky - cfg_pad;
          ix = ox*cfg_stride + kx - cfg_pad;
          if (iy >= 0 && iy < cfg_h && ix >= 0 && ix < cfg_w) begin
            input_index = (iy*cfg_w + ix)*cfg_c + ic;
            weight_index = ((oc*cfg_kh + ky)*cfg_kw + kx)*cfg_c + ic;
            acc <= acc + input_mem[input_index] * weight_mem[weight_index];
          end
          if (ic + 1 >= cfg_c) begin
            ic <= 0;
            if (kx + 1 >= cfg_kw) begin
              kx <= 0;
              if (ky + 1 >= cfg_kh) begin
                ky <= 0;
                if (cfg_quant_mode == 0) begin
                  if (acc > 127) output_mem[(oy*((cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1)+ox)*cfg_kn+oc] <= 127;
                  else if (acc < -128) output_mem[(oy*((cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1)+ox)*cfg_kn+oc] <= -128;
                  else output_mem[(oy*((cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1)+ox)*cfg_kn+oc] <= acc[7:0];
                end else output_mem[(oy*((cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1)+ox)*cfg_kn+oc] <= acc[7:0];
                acc <= 0;
                if (oc + 1 >= cfg_kn) begin
                  oc <= 0;
                  if (ox + 1 >= (cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1) begin
                    ox <= 0;
                    if (oy + 1 >= (cfg_h+2*cfg_pad-cfg_kh)/cfg_stride+1) begin state <= S_EMIT; output_count <= 0; end else oy <= oy + 1;
                  end else ox <= ox + 1;
                end else oc <= oc + 1;
              end else ky <= ky + 1;
            end else kx <= kx + 1;
          end else ic <= ic + 1;
        end
        S_EMIT: begin
          output_valid <= 1;
          output_data <= output_mem[output_count];
          if (output_valid && output_ready) begin
            if (output_count + 1 >= ((cfg_h+2*cfg_pad-cfg_kh)/cfg_stride+1)*((cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1)*cfg_kn) begin state <= S_IDLE; busy <= 0; done <= 1; output_valid <= 0; end else output_count <= output_count + 1;
          end
        end
      endcase
    end
  end
endmodule
