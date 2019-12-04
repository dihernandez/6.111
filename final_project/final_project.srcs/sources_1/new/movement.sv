`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/03/2019 11:20:22 PM
// Design Name: 
// Module Name: movement
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


module movement(
    input clk, rst,
    input logic p1_mvfwd,
    input logic p2_mvfwd,
    
    output logic [7:0] p1_x,
    output logic [7:0] p2_x
    );
    
    always_ff @(posedge clk) begin
        if (p1_mvfwd) begin
           p1_x <= p1_x + 3'd5;  //TODO: FIX
        end
    
    end //always
    
endmodule
