`timescale 1ns/1ps
module conv2d_stream_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, in_valid = 0, window_last = 0;
    reg signed [7:0] feature = 0, weight = 0;
    reg signed [31:0] bias = 0;
    wire in_ready, out_valid;
    wire signed [7:0] result;

    conv2d_stream #(.K_H(1), .K_W(1), .K_C(2)) dut (
        .clk, .rst_n, .in_valid, .in_ready, .feature, .weight,
        .window_last, .bias, .out_valid, .result
    );

    task send(input integer f, input integer w, input bit last);
        begin
            @(negedge clk); feature = f[7:0]; weight = w[7:0]; window_last = last; in_valid = 1;
            @(negedge clk); in_valid = 0; window_last = 0;
        end
    endtask

    initial begin
        $dumpfile("conv2d_stream.vcd"); $dumpvars(0, conv2d_stream_tb);
        repeat (2) @(negedge clk); rst_n = 1;
        bias = 1; send(2, 3, 0); send(-4, 5, 1);
        #1;
        if (!out_valid || result !== -13) $fatal(1, "unexpected result: valid=%0d result=%0d", out_valid, result);
        $display("PASS: result=%0d", result);
        $finish;
    end
endmodule
