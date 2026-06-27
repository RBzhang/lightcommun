`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// lightcomm_gt_mac_top
//
// Board-level integration wrapper that connects the validated GTX/SFP+ PHY
// stream wrapper to the 2-port network_8 MAC top (node_top).
//
// This file intentionally does not modify gtwizard_0, the existing PHY demo, or
// any FIFO IP.  Add the network_8 MAC RTL files and the required FIFO IPs in
// Vivado, then select this module as top only when you want to test MAC+PHY.
//------------------------------------------------------------------------------
module lightcomm_gt_mac_top #(
    parameter SYNC_WORD    = 32'hA31E57BD,
    parameter BROADCAST    = 8'hFF,
    parameter MAX_PAYLOAD  = 256,
    parameter LIVENESS_WIN = 5,
    parameter NODE_COUNT   = 255,
    parameter DEDUP_DEPTH  = 64,
    parameter FIFO_DEPTH   = 8192,
    parameter RX_REPORT_FIFO_DEPTH = 2048,
    parameter MAC_CLK_FREQ_HZ  = 100_000_000,
    parameter CONGEST_TIMEOUT_SEC = 5,
    // Hold node_top in reset until both GT lanes report TX and RX ready.
    parameter RESET_MAC_UNTIL_ALL_LINK_READY = 1,
    // If a PHY data word contains an 8B/10B data-byte error, perturb it before
    // passing it to MAC so the MAC CRC check will certainly reject that frame.
    parameter POISON_BAD_RX_WORD = 1,
    parameter [31:0] BAD_WORD_XOR = 32'h0000_0001
) (
    input  wire        Q3_CLK0_GTREFCLK_PAD_N_IN,
    input  wire        Q3_CLK0_GTREFCLK_PAD_P_IN,
    input  wire        DRP_CLK_IN_P,
    input  wire        DRP_CLK_IN_N,

    input  wire [1:0]  RXN_IN,
    input  wire [1:0]  RXP_IN,
    output wire [1:0]  TXN_OUT,
    output wire [1:0]  TXP_OUT,
    output wire [1:0]  sfp_tx_disable,

    // MAC/app clock domain.  All cfg/app/status ports below are synchronous to
    // mac_clk unless otherwise stated.
    input  wire        mac_clk,
    input  wire        mac_rst,

    input  wire        cfg_node_id_valid,
    input  wire [7:0]  cfg_node_id,

    input  wire        app_frame_valid,
    output wire        app_frame_ready,
    output wire        app_frame_accepted,
    output wire        app_frame_done,
    input  wire [7:0]  app_dst_id,
    input  wire [15:0] app_len16,
    output wire [15:0] app_payload_addr,
    input  wire [31:0] app_payload_data,

    output wire        app_rx_frame_valid,
    input  wire        app_rx_frame_ready,
    output wire [7:0]  app_rx_src_id,
    output wire [7:0]  app_rx_dst_id,
    output wire [15:0] app_rx_count,
    output wire [15:0] app_rx_len16,
    output wire        app_rx_payload_valid,
    input  wire        app_rx_payload_ready,
    output wire [15:0] app_rx_payload_addr,
    output wire [31:0] app_rx_payload_data,

    output wire        liveness_valid,
    output wire [7:0]  liveness_node,
    output wire        liveness_alive,
    output wire        network_congested,
    output wire        app_len_error,
    output wire        rx_overflow,

    output wire        gt0_tx_clk,
    output wire        gt0_rx_clk,
    output wire        gt1_tx_clk,
    output wire        gt1_rx_clk,
    output wire        gt0_link_ready,
    output wire        gt1_link_ready,
    output wire        all_link_ready,

    output wire [31:0] stream0_data_error_count,
    output wire [31:0] stream0_control_error_count,
    output wire [31:0] stream0_partial_drop_count,
    output wire [31:0] stream1_data_error_count,
    output wire [31:0] stream1_control_error_count,
    output wire [31:0] stream1_partial_drop_count
);

    wire [31:0] stream0_rx_data;
    wire        stream0_rx_valid;
    wire        stream0_rx_bad;
    wire [31:0] stream1_rx_data;
    wire        stream1_rx_valid;
    wire        stream1_rx_bad;

    wire [31:0] mac_out0;
    wire [31:0] mac_out1;
    wire        mac_valid_out0;
    wire        mac_valid_out1;

    wire        stream0_tx_ready;
    wire        stream1_tx_ready;

    assign all_link_ready = gt0_link_ready & gt1_link_ready;

    gtwizard_0_phy_stream_wrapper u_phy_stream (
        .Q3_CLK0_GTREFCLK_PAD_N_IN(Q3_CLK0_GTREFCLK_PAD_N_IN),
        .Q3_CLK0_GTREFCLK_PAD_P_IN(Q3_CLK0_GTREFCLK_PAD_P_IN),
        .DRP_CLK_IN_P(DRP_CLK_IN_P),
        .DRP_CLK_IN_N(DRP_CLK_IN_N),
        .RXN_IN(RXN_IN),
        .RXP_IN(RXP_IN),
        .TXN_OUT(TXN_OUT),
        .TXP_OUT(TXP_OUT),
        .sfp_tx_disable(sfp_tx_disable),
        .gt0_tx_clk(gt0_tx_clk),
        .gt0_rx_clk(gt0_rx_clk),
        .gt1_tx_clk(gt1_tx_clk),
        .gt1_rx_clk(gt1_rx_clk),
        .gt0_link_ready(gt0_link_ready),
        .gt1_link_ready(gt1_link_ready),
        .stream0_tx_data(mac_out0),
        .stream0_tx_valid(mac_valid_out0),
        .stream0_tx_ready(stream0_tx_ready),
        .stream0_rx_data(stream0_rx_data),
        .stream0_rx_valid(stream0_rx_valid),
        .stream0_rx_bad(stream0_rx_bad),
        .stream1_tx_data(mac_out1),
        .stream1_tx_valid(mac_valid_out1),
        .stream1_tx_ready(stream1_tx_ready),
        .stream1_rx_data(stream1_rx_data),
        .stream1_rx_valid(stream1_rx_valid),
        .stream1_rx_bad(stream1_rx_bad),
        .stream0_data_error_count(stream0_data_error_count),
        .stream0_control_error_count(stream0_control_error_count),
        .stream0_partial_drop_count(stream0_partial_drop_count),
        .stream1_data_error_count(stream1_data_error_count),
        .stream1_control_error_count(stream1_control_error_count),
        .stream1_partial_drop_count(stream1_partial_drop_count)
    );

    wire mac_core_rst = mac_rst |
                        ((RESET_MAC_UNTIL_ALL_LINK_READY != 0) && !all_link_ready);

    // Capture node ID requests and re-issue the one-cycle node_id_valid pulse
    // after the MAC core reset is released.  This protects the case where the
    // board software/config logic presents cfg_node_id_valid before GT links are
    // ready and node_top is still held in reset.
    reg [7:0] cfg_node_id_hold;
    reg       cfg_id_seen;
    reg       mac_id_loaded;
    reg       mac_node_id_valid;

    always @(posedge mac_clk) begin
        if (mac_rst) begin
            cfg_node_id_hold  <= 8'd0;
            cfg_id_seen       <= 1'b0;
            mac_id_loaded     <= 1'b0;
            mac_node_id_valid <= 1'b0;
        end else begin
            mac_node_id_valid <= 1'b0;

            if (cfg_node_id_valid) begin
                cfg_node_id_hold <= cfg_node_id;
                cfg_id_seen      <= 1'b1;
                mac_id_loaded    <= 1'b0;
            end

            if (mac_core_rst) begin
                mac_id_loaded <= 1'b0;
            end else if (cfg_id_seen && !mac_id_loaded) begin
                mac_node_id_valid <= 1'b1;
                mac_id_loaded     <= 1'b1;
            end
        end
    end

    wire [31:0] mac_in0 = (POISON_BAD_RX_WORD && stream0_rx_bad) ?
                          (stream0_rx_data ^ BAD_WORD_XOR) : stream0_rx_data;
    wire [31:0] mac_in1 = (POISON_BAD_RX_WORD && stream1_rx_bad) ?
                          (stream1_rx_data ^ BAD_WORD_XOR) : stream1_rx_data;

    node_top #(
        .SYNC_WORD(SYNC_WORD),
        .BROADCAST(BROADCAST),
        .MAX_PAYLOAD(MAX_PAYLOAD),
        .LIVENESS_WIN(LIVENESS_WIN),
        .NODE_COUNT(NODE_COUNT),
        .DEDUP_DEPTH(DEDUP_DEPTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .RX_REPORT_FIFO_DEPTH(RX_REPORT_FIFO_DEPTH),
        .CLK_FREQ_HZ(MAC_CLK_FREQ_HZ),
        .CONGEST_TIMEOUT_SEC(CONGEST_TIMEOUT_SEC)
    ) u_mac (
        .clk(mac_clk),
        .rst(mac_core_rst),
        .node_id_valid(mac_node_id_valid),
        .node_id(cfg_node_id_hold),
        .rx_clk0(gt0_rx_clk),
        .rx_clk1(gt1_rx_clk),
        .tx_clk0(gt0_tx_clk),
        .tx_clk1(gt1_tx_clk),
        .in0(mac_in0),
        .in1(mac_in1),
        .valid_in0(stream0_rx_valid),
        .valid_in1(stream1_rx_valid),
        .app_frame_valid(app_frame_valid & !mac_core_rst),
        .app_frame_ready(app_frame_ready),
        .app_frame_accepted(app_frame_accepted),
        .app_frame_done(app_frame_done),
        .app_dst_id(app_dst_id),
        .app_len16(app_len16),
        .app_payload_addr(app_payload_addr),
        .app_payload_data(app_payload_data),
        .app_rx_frame_valid(app_rx_frame_valid),
        .app_rx_frame_ready(app_rx_frame_ready),
        .app_rx_src_id(app_rx_src_id),
        .app_rx_dst_id(app_rx_dst_id),
        .app_rx_count(app_rx_count),
        .app_rx_len16(app_rx_len16),
        .app_rx_payload_valid(app_rx_payload_valid),
        .app_rx_payload_ready(app_rx_payload_ready),
        .app_rx_payload_addr(app_rx_payload_addr),
        .app_rx_payload_data(app_rx_payload_data),
        .out0(mac_out0),
        .out1(mac_out1),
        .valid_out0(mac_valid_out0),
        .valid_out1(mac_valid_out1),
        .liveness_valid(liveness_valid),
        .liveness_node(liveness_node),
        .liveness_alive(liveness_alive),
        .network_congested(network_congested),
        .app_len_error(app_len_error),
        .rx_overflow(rx_overflow)
    );

endmodule
