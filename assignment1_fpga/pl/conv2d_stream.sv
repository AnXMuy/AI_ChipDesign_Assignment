`timescale 1ns/1ps
// One signed int8 feature/weight pair per beat; one output per window.
// A line buffer and AXI wrapper are still required for a complete overlay.
module conv2d_stream #(
    parameter integer K_H = 3,
    parameter integer K_W = 3,
    parameter integer K_C = 16
) (
    input wire clk, rst_n, in_valid,
    output wire in_ready,
    input wire signed [7:0] feature, weight,
    input wire window_last,
    input wire signed [31:0] bias,
    output reg out_valid,
    output reg signed [7:0] result
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
                end else acc <= acc + feature * weight;
            end
        end
    end
endmodule

