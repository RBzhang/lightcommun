`timescale 1ns / 1ps

module tb_phy_8b10b_adapters;
    reg clk;
    reg rst;
    reg phy_ready;
    reg [31:0] gt_rxdata;
    reg [3:0]  gt_rxcharisk;
    reg [3:0]  gt_rxdisperr;
    reg [3:0]  gt_rxnotintable;
    reg        gt_rx_valid;

    wire [31:0] stream_rx_data;
    wire        stream_rx_valid;
    wire        stream_rx_bad;
    wire [31:0] data_error_count;
    wire [31:0] control_error_count;
    wire [31:0] partial_drop_count;

    integer errors;

    phy_8b10b_rx_adapter dut (
        .clk(clk),
        .rst(rst),
        .phy_ready(phy_ready),
        .gt_rxdata(gt_rxdata),
        .gt_rxcharisk(gt_rxcharisk),
        .gt_rxdisperr(gt_rxdisperr),
        .gt_rxnotintable(gt_rxnotintable),
        .gt_rx_valid(gt_rx_valid),
        .stream_rx_data(stream_rx_data),
        .stream_rx_valid(stream_rx_valid),
        .stream_rx_bad(stream_rx_bad),
        .data_error_count(data_error_count),
        .control_error_count(control_error_count),
        .partial_drop_count(partial_drop_count)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_word;
        input [31:0] data;
        input [3:0]  charisk;
        input [3:0]  disperr;
        input [3:0]  notintable;
        begin
            gt_rxdata       = data;
            gt_rxcharisk    = charisk;
            gt_rxdisperr    = disperr;
            gt_rxnotintable = notintable;
            gt_rx_valid     = 1'b1;
            @(posedge clk);
            #1;
            gt_rx_valid     = 1'b0;
            gt_rxdata       = 32'd0;
            gt_rxcharisk    = 4'd0;
            gt_rxdisperr    = 4'd0;
            gt_rxnotintable = 4'd0;
        end
    endtask

    task idle_cycle;
        begin
            gt_rx_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    task expect_valid;
        input [31:0] data;
        input        bad;
        begin
            if (!stream_rx_valid || stream_rx_data !== data || stream_rx_bad !== bad) begin
                $display("ERROR at %0t: expected valid data=%h bad=%b, got valid=%b data=%h bad=%b",
                         $time, data, bad, stream_rx_valid, stream_rx_data, stream_rx_bad);
                errors = errors + 1;
            end
        end
    endtask

    task expect_no_valid;
        begin
            if (stream_rx_valid) begin
                $display("ERROR at %0t: unexpected valid data=%h bad=%b", $time, stream_rx_data, stream_rx_bad);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors         = 0;
        rst            = 1'b1;
        phy_ready      = 1'b0;
        gt_rxdata       = 32'd0;
        gt_rxcharisk    = 4'd0;
        gt_rxdisperr    = 4'd0;
        gt_rxnotintable = 4'd0;
        gt_rx_valid     = 1'b0;

        repeat (4) @(posedge clk);
        rst       = 1'b0;
        phy_ready = 1'b1;
        idle_cycle();

        // Test 1: no byte shift.  The output word must match exactly.
        send_word(32'hA31E57BD, 4'h0, 4'h0, 4'h0);
        expect_valid(32'hA31E57BD, 1'b0);
        idle_cycle();
        expect_no_valid();

        // Test 2: K28.5/control bytes are ignored before data.
        send_word(32'hBCBCBCBC, 4'hF, 4'h0, 4'h0);
        expect_no_valid();
        send_word(32'h11223344, 4'h0, 4'h0, 4'h0);
        expect_valid(32'h11223344, 1'b0);

        // Test 3: data bytes cross a GT word boundary and are preceded/followed
        // by control bytes.  Ordinary data bytes are still packed in order.
        // Desired stream word = 32'hDEADBEEF, byte order EF BE AD DE.
        send_word(32'hADBEEFBC, 4'b0001, 4'h0, 4'h0);
        expect_no_valid();
        send_word(32'hBCBCBCDE, 4'b1110, 4'h0, 4'h0);
        expect_valid(32'hDEADBEEF, 1'b0);

        // Test 4: data-byte 8B/10B error marks the output word bad but keeps
        // byte count continuous so the MAC CRC can reject the frame later.
        send_word(32'h01020304, 4'h0, 4'b0100, 4'h0);
        expect_valid(32'h01020304, 1'b1);
        if (data_error_count !== 32'd1) begin
            $display("ERROR: expected data_error_count=1, got %0d", data_error_count);
            errors = errors + 1;
        end

        // Test 5: a control byte interrupts a partial data word.  The partial
        // word is dropped and the next complete word starts aligned again.
        send_word(32'hBCBC2211, 4'b1100, 4'h0, 4'h0);
        expect_no_valid();
        if (partial_drop_count !== 32'd1) begin
            $display("ERROR: expected partial_drop_count=1, got %0d", partial_drop_count);
            errors = errors + 1;
        end
        send_word(32'h55667788, 4'h0, 4'h0, 4'h0);
        expect_valid(32'h55667788, 1'b0);

        // Control-byte errors are counted separately and are not forwarded.
        send_word(32'hBCBCBCBC, 4'hF, 4'b0010, 4'h0);
        expect_no_valid();
        if (control_error_count !== 32'd1) begin
            $display("ERROR: expected control_error_count=1, got %0d", control_error_count);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: tb_phy_8b10b_adapters");
        end else begin
            $display("FAIL: tb_phy_8b10b_adapters errors=%0d", errors);
        end
        $finish;
    end
endmodule
