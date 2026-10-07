`timescale 1ns/1ps
module tb_conv;
  reg clk = 0, rst_n = 0, start = 0, input_valid = 0, weight_valid = 0, output_ready = 1;
  reg signed [7:0] input_data, weight_data;
  wire input_ready, weight_ready, output_valid, busy, done;
  wire signed [7:0] output_data;

  integer input_fd, weight_fd, expected_fd, output_fd, i, rc;
  reg [7:0] raw_byte;
  reg signed [7:0] expected_byte;
  reg [8*64-1:0] cfg_name;
  integer h, w, c, kn, kh, kw, stride, pad, quant_mode, p_kn, p_kh, p_kw, p_c;
  integer input_total, weight_total, output_total;
  integer input_accepted, weight_accepted, output_accepted;
  integer mismatch_count, first_mismatch_index, first_actual, first_expected;
  integer errors, cycle_count, timeout_cycles;
  integer pass_flag, result_code;
  integer output_index;

  conv_top #(.MAX_H(256), .MAX_W(256), .MAX_C(16), .MAX_KN(32), .MAX_KH(5), .MAX_KW(5)) dut(
    .clk(clk), .rst_n(rst_n), .start(start),
    .cfg_h(h), .cfg_w(w), .cfg_c(c), .cfg_kn(kn), .cfg_kh(kh), .cfg_kw(kw),
    .cfg_stride(stride), .cfg_pad(pad), .cfg_p_kn(p_kn), .cfg_p_kh(p_kh), .cfg_p_kw(p_kw), .cfg_p_c(p_c), .cfg_quant_mode(quant_mode),
    .input_data(input_data), .input_valid(input_valid), .input_ready(input_ready),
    .weight_data(weight_data), .weight_valid(weight_valid), .weight_ready(weight_ready),
    .output_data(output_data), .output_valid(output_valid), .output_ready(output_ready),
    .busy(busy), .done(done));

  always #5 clk = ~clk;

  task set_config;
    begin
      h=256; w=256; c=16; kn=32; kh=3; kw=3; stride=1; pad=1; quant_mode=0;
      p_kn=8; p_kh=3; p_kw=3; p_c=4;
      if (cfg_name == "parallel_2x") begin p_kn=2; p_kh=1; p_kw=1; p_c=1; end
      if (cfg_name == "parallel_4x") begin p_kn=4; p_kh=1; p_kw=1; p_c=1; end
      if (cfg_name == "parallel_8x") begin p_kn=8; p_kh=1; p_kw=1; p_c=1; end
      if (cfg_name == "parallel_16x") begin p_kn=16; p_kh=1; p_kw=1; p_c=1; end
      if (cfg_name == "stride2_pad0") begin stride=2; pad=0; end
      if (cfg_name == "kernel1") begin kh=1; kw=1; end
      if (cfg_name == "kernel5") begin kh=5; kw=5; end
      if (cfg_name == "truncate_quant") quant_mode=1;
      if (cfg_name == "height64") h=64;
      if (cfg_name == "width64") w=64;
      if (cfg_name == "input_channels8") c=8;
      if (cfg_name == "output_channels16") kn=16;
    end
  endtask

  task load_file_byte;
    input integer fd;
    output reg [7:0] value;
    begin
      rc=$fread(value, fd);
      if (rc != 1) begin
        $display("TB_ERROR 文件提前结束");
        errors=errors+1;
      end
    end
  endtask

  task load_input;
    begin
      for (i=0; i<input_total; i=i+1) begin
        load_file_byte(input_fd, raw_byte);
        input_data=raw_byte; input_valid=1;
        while (!input_ready) @(posedge clk);
        @(posedge clk);
        input_accepted=input_accepted+1;
      end
      input_valid=0;
      @(posedge clk);
    end
  endtask

  task load_weight;
    begin
      for (i=0; i<weight_total; i=i+1) begin
        load_file_byte(weight_fd, raw_byte);
        weight_data=raw_byte; weight_valid=1;
        while (!weight_ready) @(posedge clk);
        @(posedge clk);
        weight_accepted=weight_accepted+1;
      end
      weight_valid=0;
      @(posedge clk);
    end
  endtask

  initial begin
    if (!$value$plusargs("CFG=%s", cfg_name)) cfg_name="baseline";
    set_config();
    input_total=h*w*c;
    weight_total=kn*kh*kw*c;
    output_total=((h+2*pad-kh)/stride+1)*((w+2*pad-kw)/stride+1)*kn;
    timeout_cycles=input_total+weight_total+output_total+100000;
    input_accepted=0; weight_accepted=0; output_accepted=0; mismatch_count=0; errors=0;
    first_mismatch_index=-1; first_actual=0; first_expected=0; cycle_count=0; output_index=0;

    input_fd=$fopen({"data/",cfg_name,"/input.bin"}, "rb");
    weight_fd=$fopen({"data/",cfg_name,"/weight.bin"}, "rb");
    expected_fd=$fopen({"data/",cfg_name,"/expected.bin"}, "rb");
    output_fd=$fopen({"results/",cfg_name,"/rtl_output.bin"}, "wb");
    if (!input_fd || !weight_fd || !expected_fd || !output_fd) $fatal(1, "TB_ERROR 无法打开数据文件，请先生成配置数据");

    repeat (2) @(posedge clk);
    rst_n=1;
    @(posedge clk); start=1;
    @(posedge clk); start=0;

    load_input();
    load_weight();

    while (!done && cycle_count < timeout_cycles) begin
      @(posedge clk);
      cycle_count=cycle_count+1;
    end
    if (!done) begin
      $display("TB_ERROR 超时，未收到 done，timeout=%0d", timeout_cycles);
      errors=errors+1;
    end
    if (input_accepted != input_total) errors=errors+1;
    if (weight_accepted != weight_total) errors=errors+1;
    if (output_accepted != output_total) begin
      $display("TB_ERROR 输出数量=%0d，期望=%0d", output_accepted, output_total);
      errors=errors+1;
    end

    $fclose(input_fd); $fclose(weight_fd); $fclose(expected_fd); $fclose(output_fd);
    pass_flag=(errors==0 && mismatch_count==0 && output_accepted==output_total);
    $display("TB_SUMMARY cfg=%s input=%0d/%0d weight=%0d/%0d output=%0d/%0d cycles=%0d mismatches=%0d errors=%0d", cfg_name,input_accepted,input_total,weight_accepted,weight_total,output_accepted,output_total,cycle_count,mismatch_count,errors);
    if (first_mismatch_index >= 0) $display("TB_FIRST_MISMATCH index=%0d actual=%0d expected=%0d", first_mismatch_index, first_actual, first_expected);
    if (pass_flag) begin $display("TB_PASS cfg=%s", cfg_name); result_code=0; end
    else begin $display("TB_FAIL cfg=%s", cfg_name); result_code=1; end
    if (result_code != 0) $fatal(1, "TB_ERROR testbench 自检失败");
    $finish;
  end

  always @(posedge clk) begin
    if (output_valid && output_ready) begin
      $fwrite(output_fd, "%c", output_data);
      load_file_byte(expected_fd, raw_byte);
      expected_byte = raw_byte;
      if (output_data !== expected_byte) begin
        mismatch_count=mismatch_count+1;
        if (first_mismatch_index < 0) begin
          first_mismatch_index=output_index;
          first_actual=output_data;
          first_expected=expected_byte;
        end
      end
      output_index=output_index+1;
      output_accepted=output_accepted+1;
    end
  end
endmodule
