module linebuffer(
    input i_clk,
    input i_rst,
    input [7:0] i_data,
    input i_data_valid,
    output [23:0] o_data,
    input i_rd_data
);

reg [7:0] line [511:0]; // Line buffer memory
reg [8:0] wrpntr;
reg [8:0] rdpntr;

// --------------------------------------------------------
// 1. Write Pointer Logic (Fixing the Red 'X' Issue)
// --------------------------------------------------------
always @(posedge i_clk) begin
    if (i_rst) begin
        wrpntr <= 'd0;        // Reset pointer to 0
    end else if (i_data_valid) begin
        wrpntr <= wrpntr + 'd1; // Increment pointer
    end
end

// --------------------------------------------------------
// 2. Read Pointer Logic
// --------------------------------------------------------
always @(posedge i_clk) begin
    if (i_rst) begin
        rdpntr <= 'd0;        // Reset pointer to 0
    end else if (i_rd_data) begin
        rdpntr <= rdpntr + 'd1; // Increment pointer
    end
end

// --------------------------------------------------------
// 3. Memory Write Logic
// --------------------------------------------------------
always @(posedge i_clk) begin
    if (i_data_valid) begin
        line[wrpntr] <= i_data; // Write data to memory
    end
end

// --------------------------------------------------------
// 4. Read Logic
// --------------------------------------------------------
// Combinational read to avoid latency, as you requested
assign o_data = {line[rdpntr],line[rdpntr+1], line[rdpntr+2]};

endmodule