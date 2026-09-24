`timescale 1ns/1ps
module conv2d_stream_tb;
    parameter integer H=4, W=5, C=2, KN=3, KH=3, KW=3, PAD=1, STRIDE=1;
    localparam integer XN=H*W*C, WN=KN*KH*KW*C, ON=((H+2*PAD-KH)/STRIDE+1)*((W+2*PAD-KW)/STRIDE+1)*KN;
    reg clk=0; always #1 clk=~clk;
    reg rst_n=0,start=0,xv=0,wv=0,bv=0;
    reg [$clog2(XN)-1:0] xa; reg [$clog2(WN)-1:0] wa; reg [$clog2(KN)-1:0] ba;
    reg signed [7:0] xd,wd; reg signed [31:0] bd;
    wire busy,done,ov; wire [$clog2(ON)-1:0] oa; wire signed [7:0] od;
    reg [7:0] xhex [0:XN-1], whex [0:WN-1], ohex [0:ON-1]; reg [31:0] bhex [0:KN-1];
    integer i, count, errors;
    conv2d_stream #(.H(H),.W(W),.C(C),.KN(KN),.KH(KH),.KW(KW),.PAD(PAD),.STRIDE(STRIDE)) dut(
      .clk,.rst_n,.start,.x_load_valid(xv),.x_load_addr(xa),.x_load_data(xd),
      .w_load_valid(wv),.w_load_addr(wa),.w_load_data(wd),.b_load_valid(bv),.b_load_addr(ba),.b_load_data(bd),
      .busy,.done,.out_valid(ov),.out_addr(oa),.out_data(od));
    initial begin
      $readmemh("input.hex",xhex); $readmemh("weight.hex",whex); $readmemh("bias.hex",bhex); $readmemh("golden.hex",ohex);
      repeat(3) @(negedge clk); rst_n=1;
      for(i=0;i<XN;i=i+1) begin @(negedge clk); xv=1;xa=$clog2(XN)'(i);xd=xhex[i]; end
      @(negedge clk); xv=0;
      for(i=0;i<WN;i=i+1) begin @(negedge clk); wv=1;wa=$clog2(WN)'(i);wd=whex[i]; end
      @(negedge clk); wv=0;
      for(i=0;i<KN;i=i+1) begin @(negedge clk); bv=1;ba=$clog2(KN)'(i);bd=bhex[i]; end
      @(negedge clk); bv=0; start=1; @(negedge clk); start=0;
      count=0; errors=0;
      wait(done); repeat(3) @(posedge clk);
      if(count != ON) $fatal(1,"output count %0d != %0d",count,ON);
      if(errors != 0) $fatal(1,"mismatches %0d",errors);
      $display("PASS: %0d outputs compared",count); $finish;
    end
    always @(posedge clk) if(ov) begin count=count+1; if($signed(od) !== $signed(ohex[oa])) begin errors=errors+1; $display("mismatch addr=%0d got=%0d exp=%0d",oa,od,$signed(ohex[oa])); end end
endmodule
