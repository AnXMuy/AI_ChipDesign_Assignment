`timescale 1ns/1ps
// A compact synthesizable single-output-pixel engine.
// The controller accepts one complete K_H*K_W*K_C window at a time and emits
// one saturated int8 result. A software or DMA front-end can slide the window.
module conv2d_stream #(
    parameter integer K_H = 3,
    parameter integer K_W = 3,
    parameter integer K_C = 16
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         in_valid,
    output wire                         in_ready,
    input  wire signed [7:0]            feature,
    input  wire signed [7:0]            weight,
    input  wire                         window_last,
    input  wire signed [31:0]           bias,
    output reg                          out_valid,
    output reg signed [7:0]             result
);
    reg signed [31:0] acc;
    assign in_ready = ~out_valid;

    function automatic signed [7:0] sat8(input signed [31:0] value);
        begin
            if (value > 127) sat8 = 8'sd127;
            else if (value < -128) sat8 = -8'sd128;
            else sat8 = value[7:0];
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            acc <= 0;
            result <= 0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (in_valid && in_ready) begin
                if (window_last) begin
                    result <= sat8(acc + feature * weight + bias);
                    out_valid <= 1'b1;
                    acc <= 0;
                end else begin
                    acc <= acc + feature * weight;
                end
            end
        end
    end
endmodule
