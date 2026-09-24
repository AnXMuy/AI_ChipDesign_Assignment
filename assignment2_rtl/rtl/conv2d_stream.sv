`timescale 1ns/1ps
// Complete board-independent NHWC/HWIO int8 convolution simulator.
// Load all tensors, pulse start, then collect one saturated output per cycle.
module conv2d_stream #(
    parameter integer H=256, W=256, C=16, KN=32, KH=3, KW=3,
    parameter integer PAD=1, STRIDE=1,
    parameter integer OH=(H+2*PAD-KH)/STRIDE+1,
    parameter integer OW=(W+2*PAD-KW)/STRIDE+1
) (
    input wire clk, rst_n, start,
    input wire x_load_valid, input wire [$clog2(H*W*C)-1:0] x_load_addr, input wire signed [7:0] x_load_data,
    input wire w_load_valid, input wire [$clog2(KN*KH*KW*C)-1:0] w_load_addr, input wire signed [7:0] w_load_data,
    input wire b_load_valid, input wire [$clog2(KN)-1:0] b_load_addr, input wire signed [31:0] b_load_data,
    output reg busy, done, out_valid,
    output reg [$clog2(OH*OW*KN)-1:0] out_addr,
    output reg signed [7:0] out_data
);
    reg signed [7:0] xm [0:H*W*C-1];
    reg signed [7:0] wm [0:KN*KH*KW*C-1];
    reg signed [31:0] bm [0:KN-1];
    integer oy,ox,oc,ky,kx,ic,iy,ix,xi,wi;
    reg signed [31:0] acc, term;
    function automatic signed [7:0] sat8(input signed [31:0] v);
        begin if(v>127) sat8=127; else if(v < -128) sat8=-128; else sat8=v[7:0]; end
    endfunction
    always @(posedge clk) begin
        if(!rst_n) begin busy<=0; done<=0; out_valid<=0; oy<=0;ox<=0;oc<=0;ky<=0;kx<=0;ic<=0;acc<=0; end
        else begin
            done<=0; out_valid<=0;
            if(x_load_valid&&!busy) xm[x_load_addr]<=x_load_data;
            if(w_load_valid&&!busy) wm[w_load_addr]<=w_load_data;
            if(b_load_valid&&!busy) bm[b_load_addr]<=b_load_data;
            if(start&&!busy) begin busy<=1;oy<=0;ox<=0;oc<=0;ky<=0;kx<=0;ic<=0;acc<=0; end
            else if(busy) begin
                iy=oy*STRIDE+ky-PAD; ix=ox*STRIDE+kx-PAD;
                if(iy>=0&&iy<H&&ix>=0&&ix<W) begin
                    xi=(iy*W+ix)*C+ic; wi=((ky*KW+kx)*C+ic)*KN+oc;
                    term = acc + xm[xi]*wm[wi];
                    acc<=term;
                end
                else term = acc;
                if(ic==C-1) begin ic<=0;
                    if(kx==KW-1) begin kx<=0;
                        if(ky==KH-1) begin ky<=0;
                            out_data<=sat8(term+bm[oc]); out_addr<=$clog2(OH*OW*KN)'((oy*OW+ox)*KN+oc); out_valid<=1; acc<=0;
                            if(oc==KN-1) begin oc<=0;
                                if(ox==OW-1) begin ox<=0; if(oy==OH-1) begin oy<=0;busy<=0;done<=1;end else oy<=oy+1; end
                                else ox<=ox+1;
                            end else oc<=oc+1;
                        end else ky<=ky+1;
                    end else kx<=kx+1;
                end else ic<=ic+1;
            end
        end
    end
endmodule
