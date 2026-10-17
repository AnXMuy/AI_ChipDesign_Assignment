`timescale 1ns/1ps

// 自校验平台：同步读存储器、输出协议检查、定点值与原始累加双重比较。
module tb_conv #(
    parameter integer H = 8,
    parameter integer W = 8,
    parameter integer CIN = 16,
    parameter integer KERNEL_H = 3,
    parameter integer KERNEL_W = 3,
    parameter integer KERNELS = 32,
    parameter integer COUT = KERNELS,
    parameter integer PAD = 1,
    parameter integer STRIDE = 1,
    parameter integer SHIFT = 8,
    parameter integer LANES = 16,
    parameter integer OH = (H + 2*PAD - KERNEL_H)/STRIDE + 1,
    parameter integer OW = (W + 2*PAD - KERNEL_W)/STRIDE + 1,
    parameter integer IFM_BASE = 17,
    parameter integer KNL_BASE = 29,
    parameter integer OFM_BASE = 43,
    parameter integer RUNS = 2,
    parameter integer RESET_BETWEEN_RUNS = 1
);
    localparam integer IFM_WORDS = (H + 2*PAD)*(W + 2*PAD);
    localparam integer KNL_WORDS = KERNELS*KERNEL_H*KERNEL_W;
    localparam integer OUT_WORDS = OH*OW;
    localparam integer OUTPUTS = OUT_WORDS*COUT;
    localparam integer EXPECTED_CYCLES = OUTPUTS*(KERNEL_H*KERNEL_W*((CIN+LANES-1)/LANES+2)+1)+1;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst = 1, start = 0, done;
    logic ifm_vld, knl_vld, ofm_vld;
    logic [19:0] ifm_addr, knl_addr, ofm_addr;
    logic [CIN*8-1:0] ifm_data, knl_data;
    logic [7:0] ofm_data;
    logic [KERNELS-1:0] ofm_strb;
    logic signed [31:0] ofm_acc;
    logic [CIN*8-1:0] ifm_mem [0:IFM_WORDS-1];
    logic [CIN*8-1:0] knl_mem [0:KNL_WORDS-1];
    logic [COUT*8-1:0] golden [0:OUT_WORDS-1];
    logic [COUT*32-1:0] golden_acc [0:OUT_WORDS-1];
    logic [COUT*8-1:0] output_mem [0:OUT_WORDS-1];
    logic [COUT-1:0] seen [0:OUT_WORDS-1];
    string ifm_path, kernel_path, golden_path, golden_acc_path;
    string output_path, metrics_path, vcd_path;
    integer cycles = 0, output_count = 0, errors = 0, completed_runs = 0;
    integer trace_cycles = 400;
    integer output_fd, metrics_fd;
    integer position, channel, bit_count;
    bit active = 0, run_complete = 0, tracing = 0;

    conv #(.H(H), .W(W), .CIN(CIN), .KERNEL_H(KERNEL_H), .KERNEL_W(KERNEL_W),
        .KERNELS(KERNELS), .COUT(COUT), .PAD(PAD), .STRIDE(STRIDE),
        .SHIFT(SHIFT), .LANES(LANES), .OH(OH), .OW(OW)) dut (
        .clk_i(clk), .rst_i(rst), .cfg_conv_start_i(start),
        .cfg_ifm_addr_i(20'(IFM_BASE)), .cfg_knl_addr_i(20'(KNL_BASE)),
        .cfg_ofm_addr_i(20'(OFM_BASE)), .cfg_conv_done_o(done),
        .ifm_vld_o(ifm_vld), .ifm_addr_o(ifm_addr), .ifm_data_i(ifm_data),
        .knl_vld_o(knl_vld), .knl_addr_o(knl_addr), .knl_data_i(knl_data),
        .ofm_vld_o(ofm_vld), .ofm_addr_o(ofm_addr), .ofm_data_o(ofm_data),
        .ofm_strb_o(ofm_strb), .ofm_acc_o(ofm_acc)
    );

    // 基址只参与总线地址，文件从本地存储器零下标开始装载。
    always @(posedge clk) begin
        if (ifm_vld) begin
            if ((^ifm_addr) === 1'bx || ifm_addr < IFM_BASE || ifm_addr >= IFM_BASE+IFM_WORDS)
                $fatal(1, "IFM address out of range: %h", ifm_addr);
            ifm_data <= ifm_mem[ifm_addr-IFM_BASE];
        end
        if (knl_vld) begin
            if ((^knl_addr) === 1'bx || knl_addr < KNL_BASE || knl_addr >= KNL_BASE+KNL_WORDS)
                $fatal(1, "kernel address out of range: %h", knl_addr);
            knl_data <= knl_mem[knl_addr-KNL_BASE];
        end
        if (rst) begin
            if (ofm_vld || done) $fatal(1, "output asserted during reset");
            active = 0;
        end else begin
            if ((^{done, ifm_vld, knl_vld, ofm_vld}) === 1'bx)
                $fatal(1, "unknown control signal done=%b ifm=%b knl=%b ofm=%b state=%b", done, ifm_vld, knl_vld, ofm_vld, dut.state_q);
            if (ifm_vld !== knl_vld) $fatal(1, "unpaired memory request");
            if (start && !active) begin
                cycles = 0;
                output_count = 0;
                active = 1;
                run_complete = 0;
                for (integer i = 0; i < OUT_WORDS; i = i+1) begin
                    seen[i] = '0;
                    output_mem[i] = '0;
                end
            end else if (active) cycles = cycles + 1;
            if (active && cycles > EXPECTED_CYCLES+16)
                $fatal(1, "timeout at cycle %0d", cycles);
            if (tracing && active && cycles == trace_cycles) $dumpoff;
            if (ofm_vld) begin
                if (!active) $fatal(1, "output outside active convolution");
                if ((^{ofm_addr, ofm_strb, ofm_data, ofm_acc}) === 1'bx)
                    $fatal(1, "unknown output");
                if (ofm_addr < OFM_BASE || ofm_addr >= OFM_BASE+OUT_WORDS)
                    $fatal(1, "output address out of range");
                position = ofm_addr-OFM_BASE;
                bit_count = 0;
                channel = -1;
                for (integer c = 0; c < KERNELS; c = c+1)
                    if (ofm_strb[c]) begin bit_count = bit_count+1; channel = c; end
                if (bit_count != 1 || channel >= COUT)
                    $fatal(1, "invalid channel strobe: %h", ofm_strb);
                if (seen[position][channel]) $fatal(1, "duplicate output");
                if (position != output_count/COUT || channel != output_count%COUT)
                    $fatal(1, "output traversal order mismatch");
                seen[position][channel] = 1;
                output_mem[position][channel*8 +: 8] = ofm_data;
                if (ofm_data !== golden[position][channel*8 +: 8]) begin
                    errors = errors+1;
                    if (errors <= 10) $display("int8 mismatch pos=%0d ch=%0d got=%0d expected=%0d", position, channel,
                        $signed(ofm_data), $signed(golden[position][channel*8 +: 8]));
                end
                if (ofm_acc !== golden_acc[position][channel*32 +: 32]) begin
                    errors = errors+1;
                    if (errors <= 10) $display("acc mismatch pos=%0d ch=%0d got=%0d expected=%0d", position, channel,
                        ofm_acc, $signed(golden_acc[position][channel*32 +: 32]));
                end
                output_count = output_count+1;
                if (tracing && output_count == OUTPUTS) $dumpon;
            end
            if (done) begin
                if (!active || output_count != OUTPUTS) $fatal(1, "premature or duplicate done");
                if (cycles != EXPECTED_CYCLES) $fatal(1, "cycle mismatch got=%0d expected=%0d", cycles, EXPECTED_CYCLES);
                for (integer i = 0; i < OUT_WORDS; i = i+1)
                    if (seen[i] !== {COUT{1'b1}}) $fatal(1, "missing output");
                active = 0;
                completed_runs = completed_runs+1;
                run_complete = 1;
                $display("run=%0d cycles=%0d outputs=%0d errors=%0d", completed_runs, cycles, output_count, errors);
            end
        end
    end

    initial begin
        if (H < 1 || W < 1 || CIN < 1 || COUT < 1 || COUT > KERNELS || LANES < 1 || OH < 1 || OW < 1 || RUNS < 1)
            $fatal(1, "invalid dimensions");
        if (!$value$plusargs("IFM=%s", ifm_path)) $fatal(1, "missing +IFM");
        if (!$value$plusargs("KERNEL=%s", kernel_path)) $fatal(1, "missing +KERNEL");
        if (!$value$plusargs("GOLDEN=%s", golden_path)) $fatal(1, "missing +GOLDEN");
        if (!$value$plusargs("GOLDEN_ACC=%s", golden_acc_path)) $fatal(1, "missing +GOLDEN_ACC");
        if (!$value$plusargs("OUTPUT=%s", output_path)) $fatal(1, "missing +OUTPUT");
        if (!$value$plusargs("METRICS=%s", metrics_path)) $fatal(1, "missing +METRICS");
        $readmemh(ifm_path, ifm_mem);
        $readmemh(kernel_path, knl_mem);
        $readmemh(golden_path, golden);
        $readmemh(golden_acc_path, golden_acc);
        if ($value$plusargs("VCD=%s", vcd_path)) begin
            tracing = 1;
            if (!$value$plusargs("TRACE_CYCLES=%d", trace_cycles)) trace_cycles = 400;
            $dumpfile(vcd_path);
            // 不递归展开整个平台，避免存储器和大输入向量污染波形。
            $dumpvars(0, clk, rst, start, done, ifm_vld, ifm_addr, knl_vld, knl_addr,
                ofm_vld, ofm_addr, ofm_strb, ofm_data, ofm_acc,
                dut.state_q, dut.oh_q, dut.ow_q, dut.oc_q, dut.kh_q, dut.kw_q, dut.group_q, dut.acc_q);
        end
        @(negedge clk); rst = 1;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (2) @(negedge clk);
        for (integer run = 0; run < RUNS; run = run+1) begin
            if (run > 0 && RESET_BETWEEN_RUNS) begin
                rst = 1;
                repeat (2) @(negedge clk);
                rst = 0;
                repeat (2) @(negedge clk);
            end
            run_complete = 0;
            if (tracing) $dumpon;
            start = 1;
            @(negedge clk); start = 0;
            wait (run_complete);
            repeat (3) @(negedge clk);
        end
        output_fd = $fopen(output_path, "w");
        if (!output_fd) $fatal(1, "cannot open output file");
        for (integer i = 0; i < OUT_WORDS; i = i+1) $fdisplay(output_fd, "%h", output_mem[i]);
        $fclose(output_fd);
        metrics_fd = $fopen(metrics_path, "w");
        if (!metrics_fd) $fatal(1, "cannot open metrics file");
        $fdisplay(metrics_fd, "{\"cycles\":%0d,\"expected_cycles\":%0d,\"output_count\":%0d,\"errors\":%0d,\"runs\":%0d,\"lanes\":%0d,\"clock_period_ns\":10}",
            cycles, EXPECTED_CYCLES, output_count, errors, completed_runs, LANES);
        $fclose(metrics_fd);
        if (errors != 0) $fatal(1, "FAIL: %0d mismatches", errors);
        $display("PASS");
        $finish;
    end

    // 独立墙钟超时也能捕获启动信号或状态机完全失效的情况。
    initial begin
        #(10.0*(RUNS*(EXPECTED_CYCLES+40.0)+100.0));
        $fatal(1, "global simulation timeout");
    end
endmodule
