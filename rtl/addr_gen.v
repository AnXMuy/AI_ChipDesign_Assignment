module addr_gen(input wire clk, input wire rst_n, input wire i_valid, output reg o_valid, output reg [31:0] o_addr, output reg o_pad);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin o_valid<=0; o_addr<=0; o_pad<=0; end
    else begin o_valid<=i_valid; o_addr<=o_addr+1; o_pad<=0; end
  end
endmodule
