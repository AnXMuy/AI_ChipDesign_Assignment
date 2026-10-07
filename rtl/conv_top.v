module conv_top #(
  parameter integer MAX_H=256, MAX_W=256, MAX_C=16, MAX_KN=32,
  parameter integer MAX_KH=5, MAX_KW=5, ACC_WIDTH=32, OUT_WIDTH=8
)(
  input wire clk, input wire rst_n, input wire start,
  input wire [15:0] cfg_h, cfg_w, cfg_c, cfg_kn, cfg_kh, cfg_kw,
  input wire [15:0] cfg_stride, cfg_pad,
  input wire [15:0] cfg_p_kn, cfg_p_kh, cfg_p_kw, cfg_p_c,
  input wire [1:0] cfg_quant_mode,
  input wire signed [7:0] input_data, input wire input_valid, output wire input_ready,
  input wire signed [7:0] weight_data, input wire weight_valid, output wire weight_ready,
  output reg signed [7:0] output_data, output reg output_valid, input wire output_ready,
  output reg busy, output reg done
);
  localparam integer INPUT_CAP=MAX_H*MAX_W*MAX_C;
  localparam integer WEIGHT_CAP=MAX_KN*MAX_KH*MAX_KW*MAX_C;
  localparam integer OUTPUT_CAP=MAX_H*MAX_W*MAX_KN;
  reg signed [7:0] input_mem[0:INPUT_CAP-1];
  reg signed [7:0] weight_mem[0:WEIGHT_CAP-1];
  reg signed [7:0] output_mem[0:OUTPUT_CAP-1];
  reg signed [ACC_WIDTH-1:0] partial[0:31];
  reg signed [ACC_WIDTH-1:0] next_partial;
  reg [31:0] input_count, weight_count, output_count;
  reg [31:0] oy, ox, oc_base, ky_base, kx_base, ic_base;
  reg [31:0] oc_lane, ky_lane, kx_lane, ic_lane;
  reg [3:0] state;
  integer iy, ix, input_index, weight_index, out_index;
  integer oh, ow, active_oc, active_ky, active_kx, active_ic;
  integer lane, sum_value;
  localparam S_IDLE=0, S_LOAD_X=1, S_LOAD_W=2, S_CALC=3, S_EMIT=4;

  assign input_ready=(state==S_LOAD_X);
  assign weight_ready=(state==S_LOAD_W);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state<=S_IDLE; busy<=0; done<=0; output_valid<=0; output_data<='0;
      input_count<=0; weight_count<=0; output_count<=0;
      oy<=0; ox<=0; oc_base<=0; ky_base<=0; kx_base<=0; ic_base<=0;
      oc_lane<=0; ky_lane<=0; kx_lane<=0; ic_lane<=0;
      for (lane=0; lane<32; lane=lane+1) partial[lane]<='0;
    end else begin
      done<=0;
      case (state)
        S_IDLE: begin
          output_valid<=0;
          if (start) begin state<=S_LOAD_X; busy<=1; input_count<=0; weight_count<=0; output_count<=0; end
        end
        S_LOAD_X: begin
          if (input_valid) begin
            input_mem[input_count]<=input_data;
            input_count<=input_count+1;
            if (input_count+1>=cfg_h*cfg_w*cfg_c) state<=S_LOAD_W;
          end
        end
        S_LOAD_W: begin
          if (weight_valid) begin
            weight_mem[weight_count]<=weight_data;
            weight_count<=weight_count+1;
            if (weight_count+1>=cfg_kn*cfg_kh*cfg_kw*cfg_c) begin
              state<=S_CALC; oy<=0; ox<=0; oc_base<=0; ky_base<=0; kx_base<=0; ic_base<=0;
              oc_lane<=0; ky_lane<=0; kx_lane<=0; ic_lane<=0;
              for (lane=0; lane<32; lane=lane+1) partial[lane]<='0;
            end
          end
        end
        S_CALC: begin
          oh=(cfg_h+2*cfg_pad-cfg_kh)/cfg_stride+1;
          ow=(cfg_w+2*cfg_pad-cfg_kw)/cfg_stride+1;
          active_oc=(cfg_kn-oc_base<cfg_p_kn)?cfg_kn-oc_base:cfg_p_kn;
          active_ky=(cfg_kh-ky_base<cfg_p_kh)?cfg_kh-ky_base:cfg_p_kh;
          active_kx=(cfg_kw-kx_base<cfg_p_kw)?cfg_kw-kx_base:cfg_p_kw;
          active_ic=(cfg_c-ic_base<cfg_p_c)?cfg_c-ic_base:cfg_p_c;
          for (lane=0; lane<32; lane=lane+1) begin
            if (lane<active_oc) begin
              iy=oy*cfg_stride+(ky_base+ky_lane)-cfg_pad;
              ix=ox*cfg_stride+(kx_base+kx_lane)-cfg_pad;
              if (iy>=0 && iy<cfg_h && ix>=0 && ix<cfg_w) begin
                input_index=(iy*cfg_w+ix)*cfg_c+(ic_base+ic_lane);
                weight_index=(((oc_base+lane)*cfg_kh+(ky_base+ky_lane))*cfg_kw+(kx_base+kx_lane))*cfg_c+(ic_base+ic_lane);
                partial[lane]<=partial[lane]+input_mem[input_index]*weight_mem[weight_index];
              end
            end
          end
          if (ic_lane+1>=active_ic) begin
            ic_lane<=0;
            if (kx_lane+1>=active_kx) begin
              kx_lane<=0;
              if (ky_lane+1>=active_ky) begin
                ky_lane<=0;
                if (ic_base+active_ic>=cfg_c) begin
                  ic_base<=0;
                  if (kx_base+active_kx>=cfg_kw) begin
                    kx_base<=0;
                    if (ky_base+active_ky>=cfg_kh) begin
                      ky_base<=0;
                      if (oc_base+active_oc>=cfg_kn) begin
                        oc_base<=0;
                        for (lane=0; lane<32; lane=lane+1) begin
                          if (lane<active_oc) begin
                            if (cfg_quant_mode==0) begin
                              if (partial[lane]>127) output_mem[(oy*ow+ox)*cfg_kn+oc_base+lane]<=127;
                              else if (partial[lane]<-128) output_mem[(oy*ow+ox)*cfg_kn+oc_base+lane]<=-128;
                              else output_mem[(oy*ow+ox)*cfg_kn+oc_base+lane]<=partial[lane][OUT_WIDTH-1:0];
                            end else output_mem[(oy*ow+ox)*cfg_kn+oc_base+lane]<=partial[lane][OUT_WIDTH-1:0];
                            partial[lane]<='0;
                          end
                        end
                        if (ox+1>=ow) begin ox<=0; if (oy+1>=oh) begin state<=S_EMIT; output_count<=0; end else oy<=oy+1; end else ox<=ox+1;
                      end else begin
                        oc_base<=oc_base+active_oc;
                        for (lane=0; lane<32; lane=lane+1) if (lane<active_oc) partial[lane]<='0;
                      end
                    end else ky_base<=ky_base+active_ky;
                  end else kx_base<=kx_base+active_kx;
                end else ic_base<=ic_base+active_ic;
              end else ky_lane<=ky_lane+1;
            end else kx_lane<=kx_lane+1;
          end else ic_lane<=ic_lane+1;
        end
        S_EMIT: begin
          output_valid<=1; output_data<=output_mem[output_count];
          if (output_valid && output_ready) begin
            if (output_count+1>=oh*ow*cfg_kn) begin state<=S_IDLE; busy<=0; done<=1; output_valid<=0; end else output_count<=output_count+1;
          end
        end
      endcase
    end
  end
endmodule
