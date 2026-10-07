`timescale 1ns/1ps
module tb_conv;
  parameter H=256, W=256, C=16, KN=32, KH=3, KW=3, STRIDE=1, PAD=1;
  reg clk=0, rst_n=0, start=0, input_valid=0, weight_valid=0, output_ready=1;
  reg signed [7:0] input_data, weight_data;
  wire input_ready, weight_ready, output_valid, busy, done;
  wire signed [7:0] output_data;
  integer input_fd, weight_fd, output_fd, i, rc;
  reg [7:0] raw_byte;
  conv_top #(.MAX_H(H),.MAX_W(W),.MAX_C(C),.MAX_KN(KN),.MAX_KH(KH),.MAX_KW(KW)) dut(
    .clk(clk),.rst_n(rst_n),.start(start),.cfg_h(H),.cfg_w(W),.cfg_c(C),.cfg_kn(KN),.cfg_kh(KH),.cfg_kw(KW),.cfg_stride(STRIDE),.cfg_pad(PAD),.cfg_quant_mode(0),
    .input_data(input_data),.input_valid(input_valid),.input_ready(input_ready),.weight_data(weight_data),.weight_valid(weight_valid),.weight_ready(weight_ready),.output_data(output_data),.output_valid(output_valid),.output_ready(output_ready),.busy(busy),.done(done));
  always #5 clk = ~clk;
  task load_input;
    begin
      for (i=0; i<H*W*C; i=i+1) begin
        rc=$fread(raw_byte,input_fd); input_data=raw_byte; input_valid=1;
        @(posedge clk); while(!input_ready) @(posedge clk);
      end
      input_valid=0;
    end
  endtask
  task load_weight;
    begin
      for (i=0; i<KN*KH*KW*C; i=i+1) begin
        rc=$fread(raw_byte,weight_fd); weight_data=raw_byte; weight_valid=1;
        @(posedge clk); while(!weight_ready) @(posedge clk);
      end
      weight_valid=0;
    end
  endtask
  initial begin
    input_fd=$fopen("data/baseline/input.bin","rb"); weight_fd=$fopen("data/baseline/weight.bin","rb"); output_fd=$fopen("results/baseline/rtl_output.bin","wb");
    if (!input_fd || !weight_fd || !output_fd) $fatal(1,"文件打开失败，请先生成 baseline 数据并创建 results/baseline");
    repeat(2) @(posedge clk); rst_n=1; @(posedge clk); start=1; @(posedge clk); start=0;
    load_input(); load_weight(); wait(done);
    $fclose(input_fd); $fclose(weight_fd); $fclose(output_fd); $display("仿真完成"); $finish;
  end
  always @(posedge clk) if(output_valid && output_ready) $fwrite(output_fd,"%c",output_data);
endmodule
