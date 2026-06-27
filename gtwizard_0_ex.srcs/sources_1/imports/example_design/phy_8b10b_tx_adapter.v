`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// phy_8b10b_tx_adapter
//
// Thin transmit-side bridge from a 32-bit word stream to the GT Wizard user TX
// interface.  This is intentionally not a MAC layer: it does not generate frame
// headers, CRC, SOF, or EOF.  It only forwards data words as normal 8B/10B data
// bytes and lets gtwizard_0_user_exdes generate K28.5 idle whenever no stream
// word is valid.
//------------------------------------------------------------------------------
module phy_8b10b_tx_adapter (
    input  wire        clk,
    input  wire        rst,
    input  wire        phy_ready,

    input  wire [31:0] stream_tx_data,
    input  wire        stream_tx_valid,
    output wire        stream_tx_ready,

    output reg  [31:0] gt_txdata,
    output reg  [3:0]  gt_txcharisk,
    output reg         gt_tx_valid
);

    assign stream_tx_ready = phy_ready;

    always @(posedge clk) begin
        if (rst || !phy_ready) begin
            gt_txdata    <= 32'd0;
            gt_txcharisk <= 4'b0000;
            gt_tx_valid  <= 1'b0;
        end else if (stream_tx_valid) begin
            gt_txdata    <= stream_tx_data;
            gt_txcharisk <= 4'b0000;
            gt_tx_valid  <= 1'b1;
        end else begin
            // USER_GT*_TX_VALID_IN=0 is the existing wrapper contract for idle.
            // gtwizard_0_user_exdes will transmit K28.5 idle bytes.
            gt_txdata    <= 32'd0;
            gt_txcharisk <= 4'b0000;
            gt_tx_valid  <= 1'b0;
        end
    end

endmodule
