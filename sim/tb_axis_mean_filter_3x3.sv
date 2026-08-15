`timescale 1ns/1ps

module tb_axis_mean_filter_3x3;

    localparam integer PIXEL_WIDTH = 8;
    localparam integer IMAGE_WIDTH = 8;
    localparam integer IMAGE_HEIGHT = 6;
    localparam integer INPUT_COUNT = IMAGE_WIDTH * IMAGE_HEIGHT;
    localparam integer OUTPUT_WIDTH = IMAGE_WIDTH - 2;
    localparam integer OUTPUT_HEIGHT = IMAGE_HEIGHT - 2;
    localparam integer OUTPUT_COUNT = OUTPUT_WIDTH * OUTPUT_HEIGHT;

    reg aclk = 1'b0;
    reg aresetn = 1'b0;

    reg [PIXEL_WIDTH-1:0] s_axis_tdata = '0;
    reg s_axis_tvalid = 1'b0;
    wire s_axis_tready;
    reg s_axis_tuser = 1'b0;
    reg s_axis_tlast = 1'b0;

    wire [PIXEL_WIDTH-1:0] m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready = 1'b0;
    wire m_axis_tuser;
    wire m_axis_tlast;
    wire protocol_error;

    integer image [0:INPUT_COUNT-1];
    integer expected [0:OUTPUT_COUNT-1];
    integer row;
    integer column;
    integer source_index;
    integer expected_index;
    integer window_row;
    integer window_column;
    integer window_total;
    integer received = 0;
    integer ready_cycle = 0;

    reg held_valid = 1'b0;
    reg [PIXEL_WIDTH-1:0] held_data = '0;
    reg held_user = 1'b0;
    reg held_last = 1'b0;

    always #5 aclk = ~aclk;

    axis_mean_filter_3x3 #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast),
        .protocol_error(protocol_error)
    );

    // Deterministic downstream stalls exercise both isolated and consecutive
    // backpressure cycles without relying on simulator-specific random seeds.
    always @(negedge aclk) begin
        if (!aresetn) begin
            ready_cycle <= 0;
            m_axis_tready <= 1'b0;
        end else begin
            ready_cycle <= ready_cycle + 1;
            m_axis_tready <= ((ready_cycle % 7) != 2) &&
                             ((ready_cycle % 11) != 5) &&
                             ((ready_cycle % 11) != 6);
        end
    end

    // Scoreboard plus an explicit AXI stability check.
    always @(posedge aclk) begin
        if (!aresetn) begin
            received = 0;
            held_valid = 1'b0;
        end else begin
            if (held_valid) begin
                if (!m_axis_tvalid ||
                    (m_axis_tdata !== held_data) ||
                    (m_axis_tuser !== held_user) ||
                    (m_axis_tlast !== held_last)) begin
                    $fatal(1, "AXI output changed while stalled");
                end
            end

            held_valid = m_axis_tvalid && !m_axis_tready;
            if (m_axis_tvalid && !m_axis_tready) begin
                held_data = m_axis_tdata;
                held_user = m_axis_tuser;
                held_last = m_axis_tlast;
            end

            if (m_axis_tvalid && m_axis_tready) begin
                if (received >= OUTPUT_COUNT)
                    $fatal(1, "DUT produced more pixels than expected");
                if (m_axis_tdata !== expected[received])
                    $fatal(1, "Pixel %0d: expected %0d, received %0d",
                           received, expected[received], m_axis_tdata);
                if (m_axis_tuser !== (received == 0))
                    $fatal(1, "Pixel %0d: incorrect SOF sideband", received);
                if (m_axis_tlast !== ((received % OUTPUT_WIDTH) == OUTPUT_WIDTH-1))
                    $fatal(1, "Pixel %0d: incorrect EOL sideband", received);
                received = received + 1;
            end
        end
    end

    initial begin
        // Generate a non-trivial but reproducible frame.
        for (row = 0; row < IMAGE_HEIGHT; row = row + 1) begin
            for (column = 0; column < IMAGE_WIDTH; column = column + 1) begin
                image[row*IMAGE_WIDTH + column] =
                    (row*29 + column*7 + row*column*3) % 256;
            end
        end

        // Independent nested-loop reference implementation.
        expected_index = 0;
        for (row = 0; row < OUTPUT_HEIGHT; row = row + 1) begin
            for (column = 0; column < OUTPUT_WIDTH; column = column + 1) begin
                window_total = 0;
                for (window_row = 0; window_row < 3; window_row = window_row + 1) begin
                    for (window_column = 0; window_column < 3;
                         window_column = window_column + 1) begin
                        window_total = window_total +
                            image[(row+window_row)*IMAGE_WIDTH + column+window_column];
                    end
                end
                expected[expected_index] = window_total / 9;
                expected_index = expected_index + 1;
            end
        end

        repeat (4) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;

        for (source_index = 0; source_index < INPUT_COUNT;
             source_index = source_index + 1) begin
            // Insert deterministic bubbles on the source as well.
            if ((source_index % 9) == 4) begin
                @(negedge aclk);
                s_axis_tvalid = 1'b0;
                @(posedge aclk);
            end

            @(negedge aclk);
            s_axis_tdata = image[source_index];
            s_axis_tuser = (source_index == 0);
            s_axis_tlast = ((source_index % IMAGE_WIDTH) == IMAGE_WIDTH-1);
            s_axis_tvalid = 1'b1;

            @(posedge aclk);
            while (!s_axis_tready)
                @(posedge aclk);
        end

        @(negedge aclk);
        s_axis_tvalid = 1'b0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;

        wait (received == OUTPUT_COUNT);
        repeat (3) @(posedge aclk);
        if (protocol_error)
            $fatal(1, "DUT reported an input framing error");

        // Counters have wrapped to the next frame. Deliberately omit SOF on
        // its first beat and verify the sticky framing diagnostic.
        @(negedge aclk);
        s_axis_tdata = '0;
        s_axis_tuser = 1'b0;
        s_axis_tlast = 1'b0;
        s_axis_tvalid = 1'b1;
        @(posedge aclk);
        while (!s_axis_tready)
            @(posedge aclk);
        @(negedge aclk);
        s_axis_tvalid = 1'b0;
        @(posedge aclk);
        if (!protocol_error)
            $fatal(1, "Malformed SOF did not set protocol_error");

        // Reset assertion must immediately invalidate outputs and diagnostics.
        @(negedge aclk);
        aresetn = 1'b0;
        #1;
        if (m_axis_tvalid || protocol_error)
            $fatal(1, "Asynchronous reset did not clear output/control state");

        $display("PASS: %0d input pixels, %0d filtered pixels, stalls/framing/reset checked",
                 INPUT_COUNT, OUTPUT_COUNT);
        $finish;
    end

    initial begin
        repeat (3000) @(posedge aclk);
        $fatal(1, "Simulation timed out after 3000 cycles");
    end

endmodule
