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
    input clk, reset_in,
    input logic p1_mvfwd, p2_mvfwd,
    input logic p1_mvbwd, p2_mvbwd,
    input logic p1_dead, p2_dead,
    input logic [6:0] p1_hp, p2_hp,
    input logic [10:0] hcount,
    input logic [9:0] vcount,
    
    output logic [7:0] p1_x,
    output logic [7:0] p2_x,
    output logic [11:0] pixel_out
    );
    
    //screen size
    // x_total = 1024 pixels             512-64= 448     1024-256= 768
    // y_total =  768 pixels             384-64= 320     768-240= 528
    // try to get a 24
    
    //player starter sprites
    logic[11:0] p1_pix, p2_pix;     //squares for now 
    blob #(.WIDTH(128), .HEIGHT(128), .COLOR(12'HF00)) //mine is approximately "dark orchid"
        player1(.x_in(p1_x), .y_in(320), //p1 starts on right side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p1_pix)
                    );
        
    blob #(.WIDTH(128), .HEIGHT(128), .COLOR(12'H00F)) //mine is approximately "dark orchid"
        player2(.x_in(p2_x), .y_in(320), //p2 starts on left side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p2_pix)
                    );
        
    assign pixel_out = p1_pix + p2_pix;     //squares are one top of each other??????
    
    always_ff @(posedge clk) begin
        if (reset_in) begin
            p1_x <= 24;
            p2_x <= 224; //previously 824 (hafway overlapping) and 10024 (more than half overlapping)
        end else begin    
            if (~p1_dead) begin
                //change 100s to hp level later
                if (p1_mvfwd && (p1_x + 100 <= p2_x) ) begin  //don't run into p2
                    p1_x <= p1_x + 100;
                end else if (p1_mvbwd && (p1_x - 100 >= 24))  begin   //as is, p1 cant run into p2 going backwards, 
                                                                    //but can run into the wall... 
                    p1_x <= p1_x - 100;
                end 
            end
    
//            if (~p2_dead) begin
//                if (p2_mvfwd && (p2_x - 100 >= p1_x) ) begin  //don't run into p2
//                    p2_x <= p2_x - 100;
//                end else if (p2_mvbwd && (p1_x + 100 <= 900))  begin   //as is, p1 cant run into p2 going backwards,
//                                                                       //but can run into the wall... 
//                    p2_x <= p2_x + 100;
//                end 
//            end
        end
    end //always
    
endmodule
