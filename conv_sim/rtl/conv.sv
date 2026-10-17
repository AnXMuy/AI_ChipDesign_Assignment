`timescale 1ns/1ps

// 定点卷积：每个存储字包含同一空间位置的全部输入通道。
module conv #(
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
    parameter integer OW = (W + 2*PAD - KERNEL_W)/STRIDE + 1
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic cfg_conv_start_i,
    input  logic [19:0] cfg_ifm_addr_i,
    input  logic [19:0] cfg_knl_addr_i,
    input  logic [19:0] cfg_ofm_addr_i,
    output logic cfg_conv_done_o,
    output logic ifm_vld_o,
    output logic [19:0] ifm_addr_o,
    input  logic [CIN*8-1:0] ifm_data_i,
    output logic knl_vld_o,
    output logic [19:0] knl_addr_o,
    input  logic [CIN*8-1:0] knl_data_i,
    output logic ofm_vld_o,
    output logic [19:0] ofm_addr_o,
    output logic [7:0] ofm_data_o,
    output logic [KERNELS-1:0] ofm_strb_o,
    output logic signed [31:0] ofm_acc_o
);
    localparam integer GROUPS = (CIN + LANES - 1)/LANES;
    localparam integer PADDED_W = W + 2*PAD;
    typedef enum logic [2:0] {IDLE, REQUEST, WAIT_DATA, CALCULATE, WRITE_OUT, DONE} state_t;
    state_t state_q;
    integer unsigned oh_q, ow_q, oc_q, kh_q, kw_q, group_q;
    logic [19:0] ifm_base_q, knl_base_q, ofm_base_q;
    logic [CIN*8-1:0] ifm_q, knl_q;
    logic signed [31:0] acc_q, group_sum, shifted;
    wire signed [15:0] product [0:LANES-1];

    // 只有 LANES 个乘法器；最后一组不满的通道用零屏蔽。
    genvar lane;
    generate for (lane = 0; lane < LANES; lane = lane + 1) begin : g_lane
        wire signed [7:0] x = (group_q*LANES + lane < CIN)
            ? $signed(ifm_q[(group_q*LANES + lane)*8 +: 8]) : 8'sd0;
        wire signed [7:0] w = (group_q*LANES + lane < CIN)
            ? $signed(knl_q[(group_q*LANES + lane)*8 +: 8]) : 8'sd0;
        assign product[lane] = x*w;
    end endgenerate

    always_comb begin
        group_sum = 32'sd0;
        for (integer n = 0; n < LANES; n = n + 1)
            group_sum = group_sum + {{16{product[n][15]}}, product[n]};
    end

    always_comb begin
        ifm_vld_o = (state_q == REQUEST);
        knl_vld_o = (state_q == REQUEST);
        ifm_addr_o = ifm_base_q + (oh_q*STRIDE + kh_q)*PADDED_W + ow_q*STRIDE + kw_q;
        knl_addr_o = knl_base_q + (oc_q*KERNEL_H + kh_q)*KERNEL_W + kw_q;
        ofm_vld_o = (state_q == WRITE_OUT);
        ofm_addr_o = ofm_base_q + oh_q*OW + ow_q;
        ofm_strb_o = '0;
        if (state_q == WRITE_OUT) ofm_strb_o[oc_q] = 1'b1;
        ofm_acc_o = acc_q;
        shifted = acc_q >>> SHIFT;
        if (shifted > 32'sd127) ofm_data_o = 8'h7f;
        else if (shifted < -32'sd128) ofm_data_o = 8'h80;
        else ofm_data_o = shifted[7:0];
        cfg_conv_done_o = (state_q == DONE);
    end

    // 请求沿后存储器更新数据，等待沿锁存，再按通道分组累加。
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state_q <= IDLE;
            oh_q <= 0; ow_q <= 0; oc_q <= 0;
            kh_q <= 0; kw_q <= 0; group_q <= 0;
            ifm_base_q <= 0; knl_base_q <= 0; ofm_base_q <= 0;
            ifm_q <= '0; knl_q <= '0; acc_q <= 0;
        end else begin
            case (state_q)
                IDLE: if (cfg_conv_start_i) begin
                    ifm_base_q <= cfg_ifm_addr_i;
                    knl_base_q <= cfg_knl_addr_i;
                    ofm_base_q <= cfg_ofm_addr_i;
                    oh_q <= 0; ow_q <= 0; oc_q <= 0;
                    kh_q <= 0; kw_q <= 0; group_q <= 0;
                    acc_q <= 0;
                    state_q <= REQUEST;
                end
                REQUEST: state_q <= WAIT_DATA;
                WAIT_DATA: begin
                    ifm_q <= ifm_data_i;
                    knl_q <= knl_data_i;
                    state_q <= CALCULATE;
                end
                CALCULATE: begin
                    acc_q <= acc_q + group_sum;
                    if (group_q == GROUPS-1) begin
                        group_q <= 0;
                        if (kw_q == KERNEL_W-1) begin
                            kw_q <= 0;
                            if (kh_q == KERNEL_H-1) begin
                                kh_q <= 0;
                                state_q <= WRITE_OUT;
                            end else begin
                                kh_q <= kh_q + 1;
                                state_q <= REQUEST;
                            end
                        end else begin
                            kw_q <= kw_q + 1;
                            state_q <= REQUEST;
                        end
                    end else group_q <= group_q + 1;
                end
                WRITE_OUT: begin
                    acc_q <= 0;
                    if (oc_q == COUT-1) begin
                        oc_q <= 0;
                        if (ow_q == OW-1) begin
                            ow_q <= 0;
                            if (oh_q == OH-1) state_q <= DONE;
                            else begin
                                oh_q <= oh_q + 1;
                                state_q <= REQUEST;
                            end
                        end else begin
                            ow_q <= ow_q + 1;
                            state_q <= REQUEST;
                        end
                    end else begin
                        oc_q <= oc_q + 1;
                        state_q <= REQUEST;
                    end
                end
                DONE: state_q <= IDLE;
                default: state_q <= IDLE;
            endcase
        end
    end
endmodule
