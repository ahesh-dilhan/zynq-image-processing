`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/22/2026 10:56:47 AM
// Design Name: 
// Module Name: conv
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


module conv(
input i_clk,
input [71:0]i_pixel_data,
input i_pixel_data_valid,
output reg [7:0] O_convolved_data,
output reg o_convolved_data_valid
);
integer i;
reg [7:0] kernel [8:0];
reg [15:0] multdata[8:0];
reg [15:0] sumdataInt;
reg [15:0] sumdata;
reg mulDataValid;
reg sumDataVlaid;
reg convolved_data_valid;


initial 
begin
    for(i=0;i<9;i=i+1)
    begin
        kernel[i]=1;
    end
end

always@ (posedge i_clk)
begin
    for(i=0;i<9;i=i+1)
    begin
        multdata[i] <= kernel[i]*i_pixel_data[i*8+:8];
    end
    mulDataValid <= i_pixel_data_valid;
    
end


 
always @(*)
begin
    sumdataInt <= 0;
    for (i=0;i<9;i=i+1)
    begin
        sumdataInt <= sumdataInt + multdata[i];
    end
end
always @(posedge i_clk)
begin
    sumdata <=sumdataInt;
    sumDataVlaid <= mulDataValid;
end

always @(posedge i_clk)
begin 
    O_convolved_data <= sumdata/9;
    o_convolved_data_valid <= sumDataVlaid;
    
end

    

endmodule
