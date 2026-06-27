`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// network8_fifo_ip_aliases
//
// Compatibility alias for network_8 MAC RTL integration.
//
// The original network_8 tx_frame_fifo.v historically instantiates a FIFO IP
// named fifo_generato_txframe.  For a new Vivado project it is clearer to create
// the IP as fifo_generator_txframe.  This wrapper keeps the original RTL module
// reference working while allowing the real Vivado IP to use the corrected name.
//
// Do not include this file if you intentionally create the Vivado IP itself with
// the old module name fifo_generato_txframe, otherwise there will be a duplicate
// module definition.
//------------------------------------------------------------------------------
module fifo_generato_txframe (
    input  wire        clk,
    input  wire        srst,
    input  wire [33:0] din,
    input  wire        wr_en,
    input  wire        rd_en,
    output wire [33:0] dout,
    output wire        full,
    output wire        empty,
    output wire [13:0] data_count
);
    fifo_generator_txframe u_fifo_generator_txframe (
        .clk(clk),
        .srst(srst),
        .din(din),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .dout(dout),
        .full(full),
        .empty(empty),
        .data_count(data_count)
    );
endmodule
