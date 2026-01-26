`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/23/2026 03:17:52 PM
// Design Name: 
// Module Name: imageControl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module imageControl(
input i_clk,
input i_rst,
input [7:0] i_pixel_data,
input i_pixel_data_valid,
output reg [71:0] o_pixel_data,
output o_pixel_data_valid,
output reg o_intr

);

reg [8:0]pixelcntr;
reg [1:0]currentLineBuffer;
reg [3:0]lineBufferDataValid;
reg [3:0]lineBufferRdData;
reg [1:0]currentRdLineBuffer;
reg [8:0]rdcntr;
reg rd_line_buffer;
reg [11:0]totalPixelCounter;
reg rdState;

wire [23:0]lB0data;
wire [23:0]lB1data;
wire [23:0]lB2data;
wire [23:0]lB3data;

localparam IDLE = 'b0,
        RD_BUFFER = 'b1;
always@(posedge i_clk)
begin
    if (i_rst)
        totalPixelCounter <= 0;
    else
    begin
        if(i_pixel_data_valid & !rd_line_buffer)
            totalPixelCounter = totalPixelCounter + 1;
        else if (!i_pixel_data_valid & rd_line_buffer)
            totalPixelCounter = totalPixelCounter - 1;
    end
end        
always@(posedge i_clk)
begin
    if (i_rst)
    begin 
        rdState <= IDLE;
        rd_line_buffer <= 1'b0;
        o_intr <= 1'b0;
    end
    else
    begin
        case(rdState)
            IDLE:begin
                o_intr <= 1'b0;
                if (totalPixelCounter >= 1536)
                begin
                    rd_line_buffer <=1'b1;
                    rdState <= RD_BUFFER;     
                end    
            end
            RD_BUFFER :begin
                if (rdcntr ==511)
                begin
                    rdState <= IDLE;
                    rd_line_buffer <=1'b0;
                    o_intr <= 1'b1;
                end
            end
        endcase    
            
        
    end
end

always@(posedge i_clk)
begin
    if (i_rst)
        pixelcntr <= 0;
    else
    begin
        if (i_pixel_data_valid)
            pixelcntr <= pixelcntr + 1;
    end
end

always@(posedge i_clk)

begin 
    if (i_rst)
        currentLineBuffer <= 0;
    else
    begin
        if(pixelcntr==511 & i_pixel_data_valid)
            currentLineBuffer <= currentLineBuffer +1;      
    end
end   

always @(*) 
begin
    lineBufferDataValid = 4'd0;
    lineBufferDataValid[currentLineBuffer] = i_pixel_data_valid;
    
end  

always @(posedge i_clk)
begin
    if (i_rst)
    begin
        rdcntr <= 0;
    end
    else
    begin 
        if (rd_line_buffer)
        
        rdcntr <= rdcntr + 1;
    end
end




always @(posedge i_clk)
begin 
    if (i_rst)
    begin
        currentRdLineBuffer <= 0;
    end
    else
    begin
        if (rdcntr == 511 & rd_line_buffer)
            currentRdLineBuffer <= currentRdLineBuffer +1;   
    end
    
end




always@(*)
begin
    case(currentRdLineBuffer)
        0: begin
            o_pixel_data = {lB2data,lB1data,lB0data};
        end
        1: begin
            o_pixel_data = {lB3data,lB2data,lB1data};
        end
        2: begin
            o_pixel_data = {lB0data,lB3data,lB2data};
        end
        3: begin
            o_pixel_data = {lB1data,lB0data,lB3data};
        end
    endcase    
end

always@(*)
begin
    case(currentRdLineBuffer)
        0:begin
            lineBufferRdData[0] = rd_line_buffer;
            lineBufferRdData[1] = rd_line_buffer;
            lineBufferRdData[2] = rd_line_buffer;
            lineBufferRdData[3] = 1'b0;
          end
        1:begin
            lineBufferRdData[0] = 1'b0;
            lineBufferRdData[1] = rd_line_buffer;
            lineBufferRdData[2] = rd_line_buffer;
            lineBufferRdData[3] = rd_line_buffer;
          end  
          
        2:begin
            lineBufferRdData[0] = rd_line_buffer;
            lineBufferRdData[1] = 1'b0;
            lineBufferRdData[2] = rd_line_buffer;
            lineBufferRdData[3] = rd_line_buffer;
          end
        3:begin
            lineBufferRdData[0] = rd_line_buffer;
            lineBufferRdData[1] = rd_line_buffer;
            lineBufferRdData[2] = 1'b0;
            lineBufferRdData[3] = rd_line_buffer; 
          end
     endcase  
 end            


linebuffer lB0(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBufferDataValid[0]),
    .o_data(lB0data),
    .i_rd_data(lineBufferRdData[0])
);

    
linebuffer lB1(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBufferDataValid[1]),
    .o_data(lB1data),
    .i_rd_data(lineBufferRdData[1])
);

linebuffer lB2(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBufferDataValid[2]),
    .o_data(lB2data),
    .i_rd_data(lineBufferRdData[2])
);

linebuffer lB3(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_data(i_pixel_data),
    .i_data_valid(lineBufferDataValid[3]),
    .o_data(lB3data),
    .i_rd_data(lineBufferRdData[3])
);

    
endmodule
