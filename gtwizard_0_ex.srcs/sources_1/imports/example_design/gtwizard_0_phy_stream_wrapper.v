`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// gtwizard_0_phy_stream_wrapper
//
// Integration wrapper for later MAC connection.  It keeps the validated
// gtwizard_0_user_exdes physical layer unchanged and exposes two transparent
// 32-bit word-stream ports.
//
// This wrapper is not intended to be the current implementation top until a MAC
// or other user logic is connected to the stream ports.  The existing
// gtwizard_0_user_demo hardware test remains independent.
//------------------------------------------------------------------------------
module gtwizard_0_phy_stream_wrapper (
    input  wire        Q3_CLK0_GTREFCLK_PAD_N_IN,
    input  wire        Q3_CLK0_GTREFCLK_PAD_P_IN,
    input  wire        DRP_CLK_IN_P,
    input  wire        DRP_CLK_IN_N,

    input  wire [1:0]  RXN_IN,
    input  wire [1:0]  RXP_IN,
    output wire [1:0]  TXN_OUT,
    output wire [1:0]  TXP_OUT,
    output wire [1:0]  sfp_tx_disable,

    output wire        gt0_tx_clk,
    output wire        gt0_rx_clk,
    output wire        gt1_tx_clk,
    output wire        gt1_rx_clk,

    output wire        gt0_link_ready,
    output wire        gt1_link_ready,

    input  wire [31:0] stream0_tx_data,
    input  wire        stream0_tx_valid,
    output wire        stream0_tx_ready,

    output wire [31:0] stream0_rx_data,
    output wire        stream0_rx_valid,
    output wire        stream0_rx_bad,

    input  wire [31:0] stream1_tx_data,
    input  wire        stream1_tx_valid,
    output wire        stream1_tx_ready,

    output wire [31:0] stream1_rx_data,
    output wire        stream1_rx_valid,
    output wire        stream1_rx_bad,

    output wire [31:0] stream0_data_error_count,
    output wire [31:0] stream0_control_error_count,
    output wire [31:0] stream0_partial_drop_count,
    output wire [31:0] stream1_data_error_count,
    output wire [31:0] stream1_control_error_count,
    output wire [31:0] stream1_partial_drop_count
);

    wire        gt0_tx_reset;
    wire        gt0_rx_reset;
    wire        gt1_tx_reset;
    wire        gt1_rx_reset;
    wire        gt0_tx_ready;
    wire        gt0_rx_ready;
    wire        gt1_tx_ready;
    wire        gt1_rx_ready;

    wire [31:0] gt0_txdata;
    wire [3:0]  gt0_txcharisk;
    wire        gt0_tx_valid;
    wire [31:0] gt1_txdata;
    wire [3:0]  gt1_txcharisk;
    wire        gt1_tx_valid;

    wire [31:0] gt0_rxdata;
    wire [3:0]  gt0_rxcharisk;
    wire [3:0]  gt0_rxdisperr;
    wire [3:0]  gt0_rxnotintable;
    wire        gt0_rx_valid;
    wire [31:0] gt1_rxdata;
    wire [3:0]  gt1_rxcharisk;
    wire [3:0]  gt1_rxdisperr;
    wire [3:0]  gt1_rxnotintable;
    wire        gt1_rx_valid;

    assign gt0_link_ready = gt0_tx_ready & gt0_rx_ready;
    assign gt1_link_ready = gt1_tx_ready & gt1_rx_ready;

    gtwizard_0_user_exdes u_gt (
        .Q3_CLK0_GTREFCLK_PAD_N_IN(Q3_CLK0_GTREFCLK_PAD_N_IN),
        .Q3_CLK0_GTREFCLK_PAD_P_IN(Q3_CLK0_GTREFCLK_PAD_P_IN),
        .DRP_CLK_IN_P(DRP_CLK_IN_P),
        .DRP_CLK_IN_N(DRP_CLK_IN_N),
        .RXN_IN(RXN_IN),
        .RXP_IN(RXP_IN),
        .TXN_OUT(TXN_OUT),
        .TXP_OUT(TXP_OUT),
        .sfp_tx_disable(sfp_tx_disable),

        .USER_GT0_TXDATA_IN(gt0_txdata),
        .USER_GT0_TXCHARISK_IN(gt0_txcharisk),
        .USER_GT0_TX_VALID_IN(gt0_tx_valid),
        .USER_GT1_TXDATA_IN(gt1_txdata),
        .USER_GT1_TXCHARISK_IN(gt1_txcharisk),
        .USER_GT1_TX_VALID_IN(gt1_tx_valid),

        .USER_GT0_RXDATA_OUT(gt0_rxdata),
        .USER_GT0_RXCHARISK_OUT(gt0_rxcharisk),
        .USER_GT0_RXDISPERR_OUT(gt0_rxdisperr),
        .USER_GT0_RXNOTINTABLE_OUT(gt0_rxnotintable),
        .USER_GT0_RX_VALID_OUT(gt0_rx_valid),
        .USER_GT1_RXDATA_OUT(gt1_rxdata),
        .USER_GT1_RXCHARISK_OUT(gt1_rxcharisk),
        .USER_GT1_RXDISPERR_OUT(gt1_rxdisperr),
        .USER_GT1_RXNOTINTABLE_OUT(gt1_rxnotintable),
        .USER_GT1_RX_VALID_OUT(gt1_rx_valid),

        .USER_GT0_TXUSRCLK2_OUT(gt0_tx_clk),
        .USER_GT0_RXUSRCLK2_OUT(gt0_rx_clk),
        .USER_GT1_TXUSRCLK2_OUT(gt1_tx_clk),
        .USER_GT1_RXUSRCLK2_OUT(gt1_rx_clk),
        .USER_GT0_TX_RESET_OUT(gt0_tx_reset),
        .USER_GT0_RX_RESET_OUT(gt0_rx_reset),
        .USER_GT1_TX_RESET_OUT(gt1_tx_reset),
        .USER_GT1_RX_RESET_OUT(gt1_rx_reset),
        .USER_GT0_TX_READY_OUT(gt0_tx_ready),
        .USER_GT0_RX_READY_OUT(gt0_rx_ready),
        .USER_GT1_TX_READY_OUT(gt1_tx_ready),
        .USER_GT1_RX_READY_OUT(gt1_rx_ready)
    );

    phy_8b10b_tx_adapter u_stream0_tx (
        .clk(gt0_tx_clk),
        .rst(gt0_tx_reset),
        .phy_ready(gt0_tx_ready),
        .stream_tx_data(stream0_tx_data),
        .stream_tx_valid(stream0_tx_valid),
        .stream_tx_ready(stream0_tx_ready),
        .gt_txdata(gt0_txdata),
        .gt_txcharisk(gt0_txcharisk),
        .gt_tx_valid(gt0_tx_valid)
    );

    phy_8b10b_tx_adapter u_stream1_tx (
        .clk(gt1_tx_clk),
        .rst(gt1_tx_reset),
        .phy_ready(gt1_tx_ready),
        .stream_tx_data(stream1_tx_data),
        .stream_tx_valid(stream1_tx_valid),
        .stream_tx_ready(stream1_tx_ready),
        .gt_txdata(gt1_txdata),
        .gt_txcharisk(gt1_txcharisk),
        .gt_tx_valid(gt1_tx_valid)
    );

    phy_8b10b_rx_adapter u_stream0_rx (
        .clk(gt0_rx_clk),
        .rst(gt0_rx_reset),
        .phy_ready(gt0_rx_ready),
        .gt_rxdata(gt0_rxdata),
        .gt_rxcharisk(gt0_rxcharisk),
        .gt_rxdisperr(gt0_rxdisperr),
        .gt_rxnotintable(gt0_rxnotintable),
        .gt_rx_valid(gt0_rx_valid),
        .stream_rx_data(stream0_rx_data),
        .stream_rx_valid(stream0_rx_valid),
        .stream_rx_bad(stream0_rx_bad),
        .data_error_count(stream0_data_error_count),
        .control_error_count(stream0_control_error_count),
        .partial_drop_count(stream0_partial_drop_count)
    );

    phy_8b10b_rx_adapter u_stream1_rx (
        .clk(gt1_rx_clk),
        .rst(gt1_rx_reset),
        .phy_ready(gt1_rx_ready),
        .gt_rxdata(gt1_rxdata),
        .gt_rxcharisk(gt1_rxcharisk),
        .gt_rxdisperr(gt1_rxdisperr),
        .gt_rxnotintable(gt1_rxnotintable),
        .gt_rx_valid(gt1_rx_valid),
        .stream_rx_data(stream1_rx_data),
        .stream_rx_valid(stream1_rx_valid),
        .stream_rx_bad(stream1_rx_bad),
        .data_error_count(stream1_data_error_count),
        .control_error_count(stream1_control_error_count),
        .partial_drop_count(stream1_partial_drop_count)
    );

endmodule
