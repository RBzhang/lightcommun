`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// phy_8b10b_rx_adapter
//
// Receive-side bridge from the GT Wizard user RX interface to a transparent
// 32-bit word stream.  This module is intentionally not a MAC layer.  It only:
//   * drops 8B/10B control bytes, such as K28.5 idle;
//   * re-packs ordinary data bytes into 32-bit words;
//   * preserves byte order so TX word 32'hA31E57BD is emitted as 32'hA31E57BD;
//   * marks an output word bad if any of its data bytes had rxdisperr or
//     rxnotintable asserted.
//
// The byte re-packer is needed because the recovered GT 32-bit word boundary can
// be byte-shifted relative to the transmitted MAC word boundary.
//------------------------------------------------------------------------------
module phy_8b10b_rx_adapter (
    input  wire        clk,
    input  wire        rst,
    input  wire        phy_ready,

    input  wire [31:0] gt_rxdata,
    input  wire [3:0]  gt_rxcharisk,
    input  wire [3:0]  gt_rxdisperr,
    input  wire [3:0]  gt_rxnotintable,
    input  wire        gt_rx_valid,

    output reg  [31:0] stream_rx_data,
    output reg         stream_rx_valid,
    output reg         stream_rx_bad,

    output reg  [31:0] data_error_count,
    output reg  [31:0] control_error_count,
    output reg  [31:0] partial_drop_count
);

    reg [31:0] pack_data;
    reg [1:0]  pack_count;
    reg        pack_bad;

    integer i;
    reg [7:0]  lane_byte;
    reg        lane_bad;
    reg [31:0] next_pack_data;
    reg [1:0]  next_pack_count;
    reg        next_pack_bad;
    reg [31:0] next_stream_data;
    reg        next_stream_valid;
    reg        next_stream_bad;
    reg [2:0]  data_error_inc;
    reg [2:0]  control_error_inc;
    reg        partial_drop_inc;

    always @(posedge clk) begin
        if (rst || !phy_ready) begin
            pack_data           <= 32'd0;
            pack_count          <= 2'd0;
            pack_bad            <= 1'b0;
            stream_rx_data      <= 32'd0;
            stream_rx_valid     <= 1'b0;
            stream_rx_bad       <= 1'b0;
            data_error_count    <= 32'd0;
            control_error_count <= 32'd0;
            partial_drop_count  <= 32'd0;
        end else begin
            stream_rx_valid <= 1'b0;
            stream_rx_bad   <= 1'b0;

            if (gt_rx_valid) begin
                next_pack_data     = pack_data;
                next_pack_count    = pack_count;
                next_pack_bad      = pack_bad;
                next_stream_data   = 32'd0;
                next_stream_valid  = 1'b0;
                next_stream_bad    = 1'b0;
                data_error_inc     = 3'd0;
                control_error_inc  = 3'd0;
                partial_drop_inc   = 1'b0;

                // Scan in physical byte order: byte0, byte1, byte2, byte3.
                for (i = 0; i < 4; i = i + 1) begin
                    case (i)
                        0: begin
                            lane_byte = gt_rxdata[7:0];
                            lane_bad  = gt_rxdisperr[0] | gt_rxnotintable[0];
                        end
                        1: begin
                            lane_byte = gt_rxdata[15:8];
                            lane_bad  = gt_rxdisperr[1] | gt_rxnotintable[1];
                        end
                        2: begin
                            lane_byte = gt_rxdata[23:16];
                            lane_bad  = gt_rxdisperr[2] | gt_rxnotintable[2];
                        end
                        default: begin
                            lane_byte = gt_rxdata[31:24];
                            lane_bad  = gt_rxdisperr[3] | gt_rxnotintable[3];
                        end
                    endcase

                    if (gt_rxcharisk[i]) begin
                        // K character/control/idle byte.  It is not part of the
                        // transparent MAC word stream.
                        if (lane_bad)
                            control_error_inc = control_error_inc + 1'b1;

                        // A control byte in the middle of a partially collected
                        // data word means the stream was interrupted before a
                        // full 32-bit word arrived.  Drop the partial word so the
                        // next data burst starts aligned at byte0 of stream word.
                        if (next_pack_count != 2'd0) begin
                            next_pack_data   = 32'd0;
                            next_pack_count  = 2'd0;
                            next_pack_bad    = 1'b0;
                            partial_drop_inc = 1'b1;
                        end
                    end else begin
                        if (lane_bad) begin
                            data_error_inc = data_error_inc + 1'b1;
                            next_pack_bad  = 1'b1;
                        end

                        case (next_pack_count)
                            2'd0: next_pack_data[7:0]   = lane_byte;
                            2'd1: next_pack_data[15:8]  = lane_byte;
                            2'd2: next_pack_data[23:16] = lane_byte;
                            default: next_pack_data[31:24] = lane_byte;
                        endcase

                        if (next_pack_count == 2'd3) begin
                            next_stream_data  = next_pack_data;
                            next_stream_valid = 1'b1;
                            next_stream_bad   = next_pack_bad | lane_bad;
                            next_pack_data    = 32'd0;
                            next_pack_count   = 2'd0;
                            next_pack_bad     = 1'b0;
                        end else begin
                            next_pack_count = next_pack_count + 1'b1;
                        end
                    end
                end

                pack_data           <= next_pack_data;
                pack_count          <= next_pack_count;
                pack_bad            <= next_pack_bad;
                stream_rx_data      <= next_stream_data;
                stream_rx_valid     <= next_stream_valid;
                stream_rx_bad       <= next_stream_bad;
                data_error_count    <= data_error_count + data_error_inc;
                control_error_count <= control_error_count + control_error_inc;
                partial_drop_count  <= partial_drop_count + partial_drop_inc;
            end
        end
    end

endmodule
