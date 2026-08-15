`timescale 1ns/1ps

// Streaming 3x3 mean filter for one-component images.
//
// Input framing follows the AXI4-Stream Video convention:
//   * tuser = 1 on the first pixel of a frame
//   * tlast = 1 on the last pixel of every input line
//
// The filter emits only pixels with a complete 3x3 neighbourhood. For an
// IMAGE_WIDTH x IMAGE_HEIGHT input, the output is therefore
// (IMAGE_WIDTH-2) x (IMAGE_HEIGHT-2). The output pixel produced while accepting
// input coordinate (x,y) is centred on input coordinate (x-1,y-1).
module axis_mean_filter_3x3 #(
    parameter integer PIXEL_WIDTH  = 8,
    parameter integer IMAGE_WIDTH  = 512,
    parameter integer IMAGE_HEIGHT = 512
) (
    input  logic                     aclk,
    input  logic                     aresetn,

    input  logic [PIXEL_WIDTH-1:0]   s_axis_tdata,
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic                     s_axis_tuser,
    input  logic                     s_axis_tlast,

    output logic [PIXEL_WIDTH-1:0]   m_axis_tdata,
    output logic                     m_axis_tvalid,
    input  logic                     m_axis_tready,
    output logic                     m_axis_tuser,
    output logic                     m_axis_tlast,

    // Sticky until reset. It reports unexpected input SOF/EOL sidebands; the
    // fixed-size counters continue to define the frame rather than resyncing.
    output logic                     protocol_error
);

    localparam integer X_COUNT_WIDTH = $clog2(IMAGE_WIDTH);
    localparam integer Y_COUNT_WIDTH = $clog2(IMAGE_HEIGHT);
    localparam integer SUM_WIDTH     = PIXEL_WIDTH + 4;

    logic [X_COUNT_WIDTH-1:0] x_count;
    logic [Y_COUNT_WIDTH-1:0] y_count;

    // The memories hold the pixels at the same x coordinate from y-1 and y-2.
    // No reset is required: their contents are not used for a valid output until
    // two complete rows have been accepted.
    logic [PIXEL_WIDTH-1:0] previous_row [0:IMAGE_WIDTH-1];
    logic [PIXEL_WIDTH-1:0] second_previous_row [0:IMAGE_WIDTH-1];

    // Two horizontal delays for each of the three active rows.
    logic [PIXEL_WIDTH-1:0] top_delay_1;
    logic [PIXEL_WIDTH-1:0] top_delay_2;
    logic [PIXEL_WIDTH-1:0] middle_delay_1;
    logic [PIXEL_WIDTH-1:0] middle_delay_2;
    logic [PIXEL_WIDTH-1:0] bottom_delay_1;
    logic [PIXEL_WIDTH-1:0] bottom_delay_2;

    wire [PIXEL_WIDTH-1:0] top_current = second_previous_row[x_count];
    wire [PIXEL_WIDTH-1:0] middle_current = previous_row[x_count];

    wire input_transfer = s_axis_tvalid && s_axis_tready;
    wire output_transfer = m_axis_tvalid && m_axis_tready;
    wire output_slot_available = !m_axis_tvalid || m_axis_tready;

    // A one-entry elastic output register. When it is occupied and the sink
    // stalls, ready goes low and every item of image state is held.
    always_comb begin
        s_axis_tready = aresetn && output_slot_available;
    end

    function automatic [SUM_WIDTH-1:0] sum_window;
        input logic [PIXEL_WIDTH-1:0] p0;
        input logic [PIXEL_WIDTH-1:0] p1;
        input logic [PIXEL_WIDTH-1:0] p2;
        input logic [PIXEL_WIDTH-1:0] p3;
        input logic [PIXEL_WIDTH-1:0] p4;
        input logic [PIXEL_WIDTH-1:0] p5;
        input logic [PIXEL_WIDTH-1:0] p6;
        input logic [PIXEL_WIDTH-1:0] p7;
        input logic [PIXEL_WIDTH-1:0] p8;
        reg [SUM_WIDTH-1:0] total;
        begin
            total = p0;
            total = total + p1;
            total = total + p2;
            total = total + p3;
            total = total + p4;
            total = total + p5;
            total = total + p6;
            total = total + p7;
            total = total + p8;
            sum_window = total;
        end
    endfunction

    initial begin : validate_parameters
        if ((PIXEL_WIDTH < 8) || ((PIXEL_WIDTH % 8) != 0))
            $error("PIXEL_WIDTH must be a positive multiple of 8 for AXI4-Stream");
        if (IMAGE_WIDTH < 3)
            $error("IMAGE_WIDTH must be at least 3");
        if (IMAGE_HEIGHT < 3)
            $error("IMAGE_HEIGHT must be at least 3");
    end

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            x_count          <= '0;
            y_count          <= '0;
            top_delay_1      <= '0;
            top_delay_2      <= '0;
            middle_delay_1   <= '0;
            middle_delay_2   <= '0;
            bottom_delay_1   <= '0;
            bottom_delay_2   <= '0;
            m_axis_tdata     <= '0;
            m_axis_tvalid    <= 1'b0;
            m_axis_tuser     <= 1'b0;
            m_axis_tlast     <= 1'b0;
            protocol_error   <= 1'b0;
        end else begin
            if (output_transfer)
                m_axis_tvalid <= 1'b0;

            if (input_transfer) begin
                // Check the sideband contract without allowing malformed input
                // to index outside either line memory.
                if (s_axis_tuser != ((x_count == 0) && (y_count == 0)))
                    protocol_error <= 1'b1;
                if (s_axis_tlast != (x_count == IMAGE_WIDTH-1))
                    protocol_error <= 1'b1;

                // Read-before-write behaviour advances the two stored rows.
                second_previous_row[x_count] <= previous_row[x_count];
                previous_row[x_count]        <= s_axis_tdata;

                if (x_count == 0) begin
                    top_delay_2    <= '0;
                    top_delay_1    <= top_current;
                    middle_delay_2 <= '0;
                    middle_delay_1 <= middle_current;
                    bottom_delay_2 <= '0;
                    bottom_delay_1 <= s_axis_tdata;
                end else begin
                    top_delay_2    <= top_delay_1;
                    top_delay_1    <= top_current;
                    middle_delay_2 <= middle_delay_1;
                    middle_delay_1 <= middle_current;
                    bottom_delay_2 <= bottom_delay_1;
                    bottom_delay_1 <= s_axis_tdata;
                end

                if ((x_count >= 2) && (y_count >= 2)) begin
                    m_axis_tdata <= sum_window(
                        top_delay_2, top_delay_1, top_current,
                        middle_delay_2, middle_delay_1, middle_current,
                        bottom_delay_2, bottom_delay_1, s_axis_tdata
                    ) / 9;
                    m_axis_tvalid <= 1'b1;
                    m_axis_tuser  <= (x_count == 2) && (y_count == 2);
                    m_axis_tlast  <= (x_count == IMAGE_WIDTH-1);
                end

                if (x_count == IMAGE_WIDTH-1) begin
                    x_count <= '0;
                    if (y_count == IMAGE_HEIGHT-1)
                        y_count <= '0;
                    else
                        y_count <= y_count + 1'b1;
                end else begin
                    x_count <= x_count + 1'b1;
                end
            end
        end
    end

endmodule
